-- Phase 2: Goals, memberships, and logs

create table public.goal_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  category text not null,
  metric_type text not null,
  metric_unit text,
  cadence text not null check (cadence in ('daily', 'weekly', 'monthly', 'custom')),
  default_target jsonb default '{}'::jsonb,
  icon text,
  created_at timestamptz default now() not null
);

create table public.user_goals (
  id uuid primary key default gen_random_uuid(),
  template_id uuid references public.goal_templates(id) on delete set null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  mode text not null check (mode in ('solo', 'group')),
  cadence text not null check (cadence in ('daily', 'weekly', 'monthly', 'custom')),
  metric_type text not null,
  metric_unit text,
  target_value numeric,
  start_value numeric,
  target_date date,
  status text not null default 'active' check (status in ('active', 'completed', 'archived')),
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

create table public.goal_memberships (
  id uuid primary key default gen_random_uuid(),
  user_goal_id uuid not null references public.user_goals(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz default now() not null,
  unique (user_goal_id, user_id)
);

create table public.logs (
  id uuid primary key default gen_random_uuid(),
  user_goal_id uuid not null references public.user_goals(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  log_date date not null default current_date,
  value numeric,
  note text,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  unique (user_goal_id, author_id, log_date)
);

alter table public.goal_templates enable row level security;
alter table public.user_goals enable row level security;
alter table public.goal_memberships enable row level security;
alter table public.logs enable row level security;

-- goal_templates: readable by all authenticated users
create policy "Authenticated users can view goal templates"
  on public.goal_templates for select
  to authenticated
  using (true);

-- Helper: check membership
create or replace function public.is_goal_member(goal_id uuid)
returns boolean as $$
  select exists (
    select 1 from public.goal_memberships
    where user_goal_id = goal_id and user_id = auth.uid()
  );
$$ language sql security definer stable;

create or replace function public.is_goal_owner(goal_id uuid)
returns boolean as $$
  select exists (
    select 1 from public.goal_memberships
    where user_goal_id = goal_id and user_id = auth.uid() and role = 'owner'
  );
$$ language sql security definer stable;

-- user_goals policies
create policy "Members can view their goals"
  on public.user_goals for select
  to authenticated
  using (public.is_goal_member(id));

create policy "Users can create goals"
  on public.user_goals for insert
  to authenticated
  with check (owner_id = auth.uid());

create policy "Owners can update goals"
  on public.user_goals for update
  to authenticated
  using (public.is_goal_owner(id));

-- goal_memberships policies
create policy "Members can view memberships for their goals"
  on public.goal_memberships for select
  to authenticated
  using (public.is_goal_member(user_goal_id));

create policy "Owners can add members"
  on public.goal_memberships for insert
  to authenticated
  with check (
    public.is_goal_owner(user_goal_id)
    or (
      user_id = auth.uid()
      and role = 'owner'
      and exists (
        select 1 from public.user_goals ug
        where ug.id = user_goal_id and ug.owner_id = auth.uid()
      )
    )
  );

create policy "Owners can remove members"
  on public.goal_memberships for delete
  to authenticated
  using (public.is_goal_owner(user_goal_id) or user_id = auth.uid());

-- logs policies
create policy "Members can view logs"
  on public.logs for select
  to authenticated
  using (public.is_goal_member(user_goal_id));

create policy "Members can create own logs"
  on public.logs for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and public.is_goal_member(user_goal_id)
  );

create policy "Authors can update own logs"
  on public.logs for update
  to authenticated
  using (author_id = auth.uid());

create policy "Authors can delete own logs"
  on public.logs for delete
  to authenticated
  using (author_id = auth.uid());

create trigger user_goals_updated_at
  before update on public.user_goals
  for each row execute function public.handle_updated_at();

create trigger logs_updated_at
  before update on public.logs
  for each row execute function public.handle_updated_at();

-- Auto-add owner membership when goal is created
create or replace function public.handle_new_user_goal()
returns trigger as $$
begin
  insert into public.goal_memberships (user_goal_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_user_goal_created
  after insert on public.user_goals
  for each row execute function public.handle_new_user_goal();

-- Allow viewing profiles of fellow goal members
create policy "Users can view profiles of goal members"
  on public.profiles for select
  using (
    exists (
      select 1 from public.goal_memberships gm1
      join public.goal_memberships gm2 on gm1.user_goal_id = gm2.user_goal_id
      where gm1.user_id = auth.uid() and gm2.user_id = profiles.id
    )
  );

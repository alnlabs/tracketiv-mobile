-- Phase 3: Comments and reactions on logs

create table public.log_comments (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.logs(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

create table public.log_reactions (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.logs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji_type text not null check (emoji_type in ('like', 'celebrate', 'support', 'fire')),
  created_at timestamptz default now() not null,
  unique (log_id, user_id, emoji_type)
);

alter table public.log_comments enable row level security;
alter table public.log_reactions enable row level security;

create or replace function public.get_log_goal_id(p_log_id uuid)
returns uuid as $$
  select user_goal_id from public.logs where id = p_log_id;
$$ language sql security definer stable;

-- log_comments policies
create policy "Members can view comments on goal logs"
  on public.log_comments for select
  to authenticated
  using (public.is_goal_member(public.get_log_goal_id(log_id)));

create policy "Members can add comments"
  on public.log_comments for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and public.is_goal_member(public.get_log_goal_id(log_id))
  );

create policy "Authors can update own comments"
  on public.log_comments for update
  to authenticated
  using (author_id = auth.uid());

create policy "Authors can delete own comments"
  on public.log_comments for delete
  to authenticated
  using (author_id = auth.uid());

-- log_reactions policies
create policy "Members can view reactions"
  on public.log_reactions for select
  to authenticated
  using (public.is_goal_member(public.get_log_goal_id(log_id)));

create policy "Members can add reactions"
  on public.log_reactions for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.is_goal_member(public.get_log_goal_id(log_id))
  );

create policy "Users can remove own reactions"
  on public.log_reactions for delete
  to authenticated
  using (user_id = auth.uid());

create trigger log_comments_updated_at
  before update on public.log_comments
  for each row execute function public.handle_updated_at();

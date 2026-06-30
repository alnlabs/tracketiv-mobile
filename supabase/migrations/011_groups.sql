-- Groups: shared containers that hold multiple goals

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

create table public.group_memberships (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz default now() not null,
  unique (group_id, user_id)
);

create table public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  invited_email text not null,
  invited_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'cancelled')),
  created_at timestamptz default now() not null,
  unique (group_id, invited_email)
);

alter table public.user_goals
  add column if not exists group_id uuid references public.groups(id) on delete set null;

alter table public.groups enable row level security;
alter table public.group_memberships enable row level security;
alter table public.group_invites enable row level security;

-- Helpers
create or replace function public.is_group_member(p_group_id uuid)
returns boolean as $$
  select exists (
    select 1 from public.group_memberships
    where group_id = p_group_id and user_id = auth.uid()
  );
$$ language sql security definer stable;

create or replace function public.is_group_owner(p_group_id uuid)
returns boolean as $$
  select exists (
    select 1 from public.group_memberships
    where group_id = p_group_id and user_id = auth.uid() and role = 'owner'
  );
$$ language sql security definer stable;

create or replace function public.is_invited_to_group(invite_email text)
returns boolean as $$
  select exists (
    select 1 from auth.users
    where id = auth.uid() and lower(email) = lower(invite_email)
  );
$$ language sql security definer stable;

-- Goal access via direct membership OR group membership
create or replace function public.is_goal_member(goal_id uuid)
returns boolean as $$
  select exists (
    select 1 from public.goal_memberships
    where user_goal_id = goal_id and user_id = auth.uid()
  )
  or exists (
    select 1 from public.user_goals ug
    join public.group_memberships gm on gm.group_id = ug.group_id
    where ug.id = goal_id
      and ug.group_id is not null
      and gm.user_id = auth.uid()
  );
$$ language sql security definer stable;

create or replace function public.is_goal_owner(goal_id uuid)
returns boolean as $$
  select exists (
    select 1 from public.goal_memberships
    where user_goal_id = goal_id and user_id = auth.uid() and role = 'owner'
  )
  or exists (
    select 1 from public.user_goals ug
    join public.group_memberships gm on gm.group_id = ug.group_id
    where ug.id = goal_id
      and ug.group_id is not null
      and gm.user_id = auth.uid()
      and gm.role = 'owner'
  );
$$ language sql security definer stable;

-- groups policies
create policy "Members can view their groups"
  on public.groups for select
  to authenticated
  using (public.is_group_member(id) or owner_id = auth.uid());

create policy "Users can create groups"
  on public.groups for insert
  to authenticated
  with check (owner_id = auth.uid());

create policy "Owners can update groups"
  on public.groups for update
  to authenticated
  using (public.is_group_owner(id));

-- group_memberships policies
create policy "Members can view group memberships"
  on public.group_memberships for select
  to authenticated
  using (public.is_group_member(group_id));

create policy "Owners can add group members"
  on public.group_memberships for insert
  to authenticated
  with check (
    public.is_group_owner(group_id)
    or (
      user_id = auth.uid()
      and role = 'owner'
      and exists (
        select 1 from public.groups g
        where g.id = group_id and g.owner_id = auth.uid()
      )
    )
  );

create policy "Owners can remove members or self leave"
  on public.group_memberships for delete
  to authenticated
  using (public.is_group_owner(group_id) or user_id = auth.uid());

-- group_invites policies
create policy "Owners can view group invites"
  on public.group_invites for select
  to authenticated
  using (public.is_group_owner(group_id) or public.is_invited_to_group(invited_email));

create policy "Owners can create group invites"
  on public.group_invites for insert
  to authenticated
  with check (public.is_group_owner(group_id) and invited_by = auth.uid());

create policy "Owners can update group invites"
  on public.group_invites for update
  to authenticated
  using (public.is_group_owner(group_id));

create policy "Owners can delete group invites"
  on public.group_invites for delete
  to authenticated
  using (public.is_group_owner(group_id));

-- Goals in a group require group membership
drop policy if exists "Users can create goals" on public.user_goals;
create policy "Users can create goals"
  on public.user_goals for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and (group_id is null or public.is_group_member(group_id))
  );

-- View profiles of fellow group members
create policy "Users can view profiles of group members"
  on public.profiles for select
  using (
    exists (
      select 1 from public.group_memberships gm1
      join public.group_memberships gm2 on gm1.group_id = gm2.group_id
      where gm1.user_id = auth.uid() and gm2.user_id = profiles.id
    )
  );

create trigger groups_updated_at
  before update on public.groups
  for each row execute function public.handle_updated_at();

create or replace function public.handle_new_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.group_memberships (group_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict (group_id, user_id) do nothing;
  return new;
end;
$$;

create trigger on_group_created
  after insert on public.groups
  for each row execute function public.handle_new_group();

-- Migrate existing group-mode goals into groups
do $$
declare
  r record;
  v_group_id uuid;
begin
  for r in
    select * from public.user_goals
    where mode = 'group' and group_id is null
  loop
    insert into public.groups (name, description, owner_id, created_at)
    values (r.title, r.description, r.owner_id, r.created_at)
    returning id into v_group_id;

    update public.user_goals set group_id = v_group_id where id = r.id;

    insert into public.group_memberships (group_id, user_id, role)
    select v_group_id, gm.user_id, gm.role
    from public.goal_memberships gm
    where gm.user_goal_id = r.id
    on conflict (group_id, user_id) do nothing;

    insert into public.group_invites (group_id, invited_email, invited_by, status, created_at)
    select v_group_id, gi.invited_email, gi.invited_by, gi.status, gi.created_at
    from public.goal_invites gi
    where gi.user_goal_id = r.id
    on conflict (group_id, invited_email) do nothing;
  end loop;
end $$;

-- Invite user to group (existing user added directly, else pending invite)
create or replace function public.invite_user_to_group(p_group_id uuid, p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_normalized text := lower(trim(p_email));
begin
  if not public.is_group_owner(p_group_id) then
    raise exception 'Only the group owner can invite members';
  end if;

  if v_normalized = '' then
    raise exception 'Email is required';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = v_normalized;

  if v_user_id is not null then
    if exists (
      select 1 from public.group_memberships
      where group_id = p_group_id and user_id = v_user_id
    ) then
      return jsonb_build_object('status', 'already_member');
    end if;

    insert into public.group_memberships (group_id, user_id, role)
    values (p_group_id, v_user_id, 'member');

    return jsonb_build_object('status', 'added', 'user_id', v_user_id);
  end if;

  insert into public.group_invites (group_id, invited_email, invited_by)
  values (p_group_id, v_normalized, auth.uid())
  on conflict (group_id, invited_email)
  do update set status = 'pending', invited_by = auth.uid(), created_at = now();

  return jsonb_build_object('status', 'invited');
end;
$$;

grant execute on function public.invite_user_to_group(uuid, text) to authenticated;

create or replace function public.get_my_group_invites()
returns table (
  id uuid,
  group_id uuid,
  group_name text,
  invited_by_name text,
  invited_email text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    gi.id,
    gi.group_id,
    g.name as group_name,
    p.display_name as invited_by_name,
    gi.invited_email,
    gi.created_at
  from public.group_invites gi
  join public.groups g on g.id = gi.group_id
  join public.profiles p on p.id = gi.invited_by
  join auth.users u on u.id = auth.uid()
  where gi.status = 'pending'
    and lower(gi.invited_email) = lower(u.email);
$$;

grant execute on function public.get_my_group_invites() to authenticated;

create or replace function public.accept_group_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite record;
begin
  select * into v_invite
  from public.group_invites
  where id = p_invite_id and status = 'pending';

  if not found then
    raise exception 'Invite not found';
  end if;

  if not public.is_invited_to_group(v_invite.invited_email) then
    raise exception 'Not authorized to accept this invite';
  end if;

  insert into public.group_memberships (group_id, user_id, role)
  values (v_invite.group_id, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  update public.group_invites
  set status = 'accepted'
  where id = p_invite_id;
end;
$$;

grant execute on function public.accept_group_invite(uuid) to authenticated;

-- Signup: also auto-join pending group invites
create or replace function public.handle_new_user()
returns trigger as $$
declare
  v_username text := lower(trim(new.raw_user_meta_data->>'username'));
  v_display_name text := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    v_username,
    split_part(new.email, '@', 1)
  );
begin
  insert into public.profiles (id, display_name, username)
  values (new.id, v_display_name, nullif(v_username, ''));

  insert into public.goal_memberships (user_goal_id, user_id, role)
  select gi.user_goal_id, new.id, 'member'
  from public.goal_invites gi
  where lower(gi.invited_email) = lower(new.email)
    and gi.status = 'pending'
  on conflict (user_goal_id, user_id) do nothing;

  update public.goal_invites
  set status = 'accepted'
  where lower(invited_email) = lower(new.email) and status = 'pending';

  insert into public.group_memberships (group_id, user_id, role)
  select gi.group_id, new.id, 'member'
  from public.group_invites gi
  where lower(gi.invited_email) = lower(new.email)
    and gi.status = 'pending'
  on conflict (group_id, user_id) do nothing;

  update public.group_invites
  set status = 'accepted'
  where lower(invited_email) = lower(new.email) and status = 'pending';

  return new;
end;
$$ language plpgsql security definer;

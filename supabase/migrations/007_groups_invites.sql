-- Groups: invites, user search, and signup auto-join

create table public.goal_invites (
  id uuid primary key default gen_random_uuid(),
  user_goal_id uuid not null references public.user_goals(id) on delete cascade,
  invited_email text not null,
  invited_by uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'cancelled')),
  created_at timestamptz default now() not null,
  unique (user_goal_id, invited_email)
);

alter table public.goal_invites enable row level security;

create or replace function public.is_invited_to_goal(invite_email text)
returns boolean as $$
  select exists (
    select 1 from auth.users
    where id = auth.uid() and lower(email) = lower(invite_email)
  );
$$ language sql security definer stable;

create policy "Owners can view goal invites"
  on public.goal_invites for select
  to authenticated
  using (public.is_goal_owner(user_goal_id) or public.is_invited_to_goal(invited_email));

create policy "Owners can create goal invites"
  on public.goal_invites for insert
  to authenticated
  with check (public.is_goal_owner(user_goal_id) and invited_by = auth.uid());

create policy "Owners can update goal invites"
  on public.goal_invites for update
  to authenticated
  using (public.is_goal_owner(user_goal_id));

create policy "Owners can delete goal invites"
  on public.goal_invites for delete
  to authenticated
  using (public.is_goal_owner(user_goal_id));

-- Search users by display name or email (for inviting)
create or replace function public.search_users_for_invite(search_term text)
returns table (
  id uuid,
  display_name text,
  avatar_url text,
  email_hint text
)
language sql
security definer
set search_path = public
as $$
  select
    p.id,
    p.display_name,
    p.avatar_url,
    split_part(u.email, '@', 1) || '@' || split_part(u.email, '@', 2) as email_hint
  from public.profiles p
  join auth.users u on u.id = p.id
  where u.id != auth.uid()
    and (
      coalesce(p.display_name, '') ilike '%' || search_term || '%'
      or u.email ilike '%' || search_term || '%'
    )
  limit 20;
$$;

grant execute on function public.search_users_for_invite(text) to authenticated;

-- Invite by email: add existing user or create pending invite
create or replace function public.invite_user_to_goal(p_goal_id uuid, p_email text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_normalized text := lower(trim(p_email));
begin
  if not public.is_goal_owner(p_goal_id) then
    raise exception 'Only the goal owner can invite members';
  end if;

  if v_normalized = '' then
    raise exception 'Email is required';
  end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = v_normalized;

  if v_user_id is not null then
    if exists (
      select 1 from public.goal_memberships
      where user_goal_id = p_goal_id and user_id = v_user_id
    ) then
      return jsonb_build_object('status', 'already_member');
    end if;

    insert into public.goal_memberships (user_goal_id, user_id, role)
    values (p_goal_id, v_user_id, 'member');

    return jsonb_build_object('status', 'added', 'user_id', v_user_id);
  end if;

  insert into public.goal_invites (user_goal_id, invited_email, invited_by)
  values (p_goal_id, v_normalized, auth.uid())
  on conflict (user_goal_id, invited_email)
  do update set status = 'pending', invited_by = auth.uid(), created_at = now();

  return jsonb_build_object('status', 'invited');
end;
$$;

grant execute on function public.invite_user_to_goal(uuid, text) to authenticated;

-- Pending invites for the logged-in user
create or replace function public.get_my_goal_invites()
returns table (
  id uuid,
  user_goal_id uuid,
  goal_title text,
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
    gi.user_goal_id,
    ug.title as goal_title,
    p.display_name as invited_by_name,
    gi.invited_email,
    gi.created_at
  from public.goal_invites gi
  join public.user_goals ug on ug.id = gi.user_goal_id
  join public.profiles p on p.id = gi.invited_by
  join auth.users u on u.id = auth.uid()
  where gi.status = 'pending'
    and lower(gi.invited_email) = lower(u.email);
$$;

grant execute on function public.get_my_goal_invites() to authenticated;

-- Accept a pending invite
create or replace function public.accept_goal_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite record;
begin
  select * into v_invite
  from public.goal_invites
  where id = p_invite_id and status = 'pending';

  if not found then
    raise exception 'Invite not found';
  end if;

  if not public.is_invited_to_goal(v_invite.invited_email) then
    raise exception 'Not authorized to accept this invite';
  end if;

  insert into public.goal_memberships (user_goal_id, user_id, role)
  values (v_invite.user_goal_id, auth.uid(), 'member')
  on conflict (user_goal_id, user_id) do nothing;

  update public.goal_invites
  set status = 'accepted'
  where id = p_invite_id;
end;
$$;

grant execute on function public.accept_goal_invite(uuid) to authenticated;

-- Auto-join invited goals on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, split_part(new.email, '@', 1));

  insert into public.goal_memberships (user_goal_id, user_id, role)
  select gi.user_goal_id, new.id, 'member'
  from public.goal_invites gi
  where lower(gi.invited_email) = lower(new.email)
    and gi.status = 'pending'
  on conflict (user_goal_id, user_id) do nothing;

  update public.goal_invites
  set status = 'accepted'
  where lower(invited_email) = lower(new.email) and status = 'pending';

  return new;
end;
$$ language plpgsql security definer;

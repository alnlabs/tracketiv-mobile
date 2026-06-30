-- Usernames: unique handle, login by username or email

alter table public.profiles
  add column if not exists username text;

create unique index if not exists profiles_username_lower_idx
  on public.profiles (lower(username))
  where username is not null;

alter table public.profiles
  add constraint profiles_username_format
  check (
    username is null
    or (
      username ~ '^[a-z][a-z0-9_]{2,29}$'
    )
  );

-- Resolve email for login (username or email identifier)
create or replace function public.get_email_for_login(p_identifier text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_identifier text := lower(trim(p_identifier));
  v_email text;
begin
  if v_identifier = '' then
    return null;
  end if;

  if position('@' in v_identifier) > 0 then
    return v_identifier;
  end if;

  select u.email into v_email
  from public.profiles p
  join auth.users u on u.id = p.id
  where lower(p.username) = v_identifier;

  return v_email;
end;
$$;

grant execute on function public.get_email_for_login(text) to anon, authenticated;

-- Check username availability (optionally exclude current user on profile update)
create or replace function public.is_username_available(
  p_username text,
  p_user_id uuid default null
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.profiles
    where lower(username) = lower(trim(p_username))
      and (p_user_id is null or id != p_user_id)
  );
$$;

grant execute on function public.is_username_available(text, uuid) to anon, authenticated;

-- Signup: store username + auto-join pending group invites
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

  return new;
end;
$$ language plpgsql security definer;

-- Include username in user search for group invites
-- Must drop first: return type changed from migration 007
drop function if exists public.search_users_for_invite(text);

create function public.search_users_for_invite(search_term text)
returns table (
  id uuid,
  display_name text,
  username text,
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
    p.username,
    p.avatar_url,
    split_part(u.email, '@', 1) || '@' || split_part(u.email, '@', 2) as email_hint
  from public.profiles p
  join auth.users u on u.id = p.id
  where u.id != auth.uid()
    and (
      coalesce(p.display_name, '') ilike '%' || search_term || '%'
      or coalesce(p.username, '') ilike '%' || search_term || '%'
      or u.email ilike '%' || search_term || '%'
    )
  limit 20;
$$;

grant execute on function public.search_users_for_invite(text) to authenticated;

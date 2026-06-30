-- In-app notifications for invites, reactions, and comments

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('group_invite', 'goal_invite', 'reaction', 'comment')),
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz default now() not null
);

create index notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index notifications_user_unread_idx
  on public.notifications (user_id)
  where read_at is null;

alter table public.notifications enable row level security;

create policy "Users can view own notifications"
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can update own notifications"
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid());

-- Inserts only via triggers / security definer functions
create policy "No direct notification inserts"
  on public.notifications for insert
  to authenticated
  with check (false);

-- Helper: resolve user id from email
create or replace function public.user_id_for_email(p_email text)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1;
$$;

create or replace function public.create_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null or p_user_id = auth.uid() then
    return;
  end if;

  insert into public.notifications (user_id, type, title, body, data)
  values (p_user_id, p_type, p_title, p_body, p_data);
end;
$$;

-- Reaction on someone else's log
create or replace function public.notify_on_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_goal_id uuid;
  v_goal_title text;
  v_actor_name text;
begin
  select l.author_id, l.user_goal_id, ug.title
  into v_author_id, v_goal_id, v_goal_title
  from public.logs l
  join public.user_goals ug on ug.id = l.user_goal_id
  where l.id = new.log_id;

  if v_author_id is null or v_author_id = new.user_id then
    return new;
  end if;

  select coalesce(p.display_name, p.username, 'Someone')
  into v_actor_name
  from public.profiles p
  where p.id = new.user_id;

  perform public.create_notification(
    v_author_id,
    'reaction',
    'New reaction',
    v_actor_name || ' reacted to your update on ' || v_goal_title,
    jsonb_build_object(
      'log_id', new.log_id,
      'goal_id', v_goal_id,
      'actor_id', new.user_id,
      'emoji_type', new.emoji_type
    )
  );

  return new;
end;
$$;

create trigger log_reactions_notify
  after insert on public.log_reactions
  for each row execute function public.notify_on_reaction();

-- Comment on someone else's log
create or replace function public.notify_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author_id uuid;
  v_goal_id uuid;
  v_goal_title text;
  v_actor_name text;
begin
  select l.author_id, l.user_goal_id, ug.title
  into v_author_id, v_goal_id, v_goal_title
  from public.logs l
  join public.user_goals ug on ug.id = l.user_goal_id
  where l.id = new.log_id;

  if v_author_id is null or v_author_id = new.author_id then
    return new;
  end if;

  select coalesce(p.display_name, p.username, 'Someone')
  into v_actor_name
  from public.profiles p
  where p.id = new.author_id;

  perform public.create_notification(
    v_author_id,
    'comment',
    'New comment',
    v_actor_name || ' commented on your update on ' || v_goal_title,
    jsonb_build_object(
      'log_id', new.log_id,
      'goal_id', v_goal_id,
      'comment_id', new.id,
      'actor_id', new.author_id
    )
  );

  return new;
end;
$$;

create trigger log_comments_notify
  after insert on public.log_comments
  for each row execute function public.notify_on_comment();

-- Group invite
create or replace function public.notify_on_group_invite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_group_name text;
  v_inviter_name text;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  v_user_id := public.user_id_for_email(new.invited_email);
  if v_user_id is null then
    return new;
  end if;

  select g.name into v_group_name
  from public.groups g
  where g.id = new.group_id;

  select coalesce(p.display_name, p.username, 'Someone')
  into v_inviter_name
  from public.profiles p
  where p.id = new.invited_by;

  perform public.create_notification(
    v_user_id,
    'group_invite',
    'Group invite',
    v_inviter_name || ' invited you to ' || coalesce(v_group_name, 'a group'),
    jsonb_build_object(
      'invite_id', new.id,
      'group_id', new.group_id
    )
  );

  return new;
end;
$$;

create trigger group_invites_notify
  after insert on public.group_invites
  for each row execute function public.notify_on_group_invite();

-- Goal invite
create or replace function public.notify_on_goal_invite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_goal_title text;
  v_inviter_name text;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  v_user_id := public.user_id_for_email(new.invited_email);
  if v_user_id is null then
    return new;
  end if;

  select ug.title into v_goal_title
  from public.user_goals ug
  where ug.id = new.user_goal_id;

  select coalesce(p.display_name, p.username, 'Someone')
  into v_inviter_name
  from public.profiles p
  where p.id = new.invited_by;

  perform public.create_notification(
    v_user_id,
    'goal_invite',
    'Goal invite',
    v_inviter_name || ' invited you to ' || coalesce(v_goal_title, 'a goal'),
    jsonb_build_object(
      'invite_id', new.id,
      'goal_id', new.user_goal_id
    )
  );

  return new;
end;
$$;

create trigger goal_invites_notify
  after insert on public.goal_invites
  for each row execute function public.notify_on_goal_invite();

-- Backfill pending invites for existing users
insert into public.notifications (user_id, type, title, body, data)
select
  u.id,
  'group_invite',
  'Group invite',
  coalesce(inviter.display_name, inviter.username, 'Someone')
    || ' invited you to ' || coalesce(g.name, 'a group'),
  jsonb_build_object('invite_id', gi.id, 'group_id', gi.group_id)
from public.group_invites gi
join public.groups g on g.id = gi.group_id
join public.profiles inviter on inviter.id = gi.invited_by
join auth.users u on lower(u.email) = lower(gi.invited_email)
where gi.status = 'pending';

insert into public.notifications (user_id, type, title, body, data)
select
  u.id,
  'goal_invite',
  'Goal invite',
  coalesce(inviter.display_name, inviter.username, 'Someone')
    || ' invited you to ' || coalesce(ug.title, 'a goal'),
  jsonb_build_object('invite_id', gi.id, 'goal_id', gi.user_goal_id)
from public.goal_invites gi
join public.user_goals ug on ug.id = gi.user_goal_id
join public.profiles inviter on inviter.id = gi.invited_by
join auth.users u on lower(u.email) = lower(gi.invited_email)
where gi.status = 'pending';

-- RPCs
create or replace function public.get_unread_notification_count()
returns int
language sql
security definer
stable
set search_path = public
as $$
  select count(*)::int
  from public.notifications
  where user_id = auth.uid() and read_at is null;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = now()
  where id = p_notification_id and user_id = auth.uid();
end;
$$;

create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = now()
  where user_id = auth.uid() and read_at is null;
end;
$$;

grant execute on function public.get_unread_notification_count() to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- Enable realtime
alter publication supabase_realtime add table public.notifications;

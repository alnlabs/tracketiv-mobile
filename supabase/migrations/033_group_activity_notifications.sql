-- Group activity in-app notifications + helper for member fan-out.

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'group_invite',
    'goal_invite',
    'reaction',
    'comment',
    'group_post',
    'group_reaction',
    'group_comment'
  ));

create or replace function public.is_group_goal(p_goal_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.user_goals ug
    where ug.id = p_goal_id
      and (ug.mode = 'group' or ug.group_id is not null)
      and ug.deleted_at is null
  );
$$;

create or replace function public.goal_member_user_ids(p_goal_id uuid)
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select distinct gm.user_id
  from public.goal_memberships gm
  where gm.user_goal_id = p_goal_id
    and gm.deleted_at is null
  union
  select distinct gm.user_id
  from public.user_goals ug
  join public.group_memberships gm on gm.group_id = ug.group_id
  where ug.id = p_goal_id
    and ug.group_id is not null
    and ug.deleted_at is null
    and gm.deleted_at is null;
$$;

create or replace function public.notify_goal_members_except(
  p_goal_id uuid,
  p_exclude_user_ids uuid[],
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
declare
  v_member_id uuid;
begin
  if not public.is_group_goal(p_goal_id) then
    return;
  end if;

  for v_member_id in
    select member_id
    from public.goal_member_user_ids(p_goal_id) as t(member_id)
    where not (member_id = any (coalesce(p_exclude_user_ids, array[]::uuid[])))
  loop
    perform public.create_notification(
      v_member_id,
      p_type,
      p_title,
      p_body,
      p_data || jsonb_build_object('goal_id', p_goal_id)
    );
  end loop;
end;
$$;

-- New log in a group goal → notify other members.
create or replace function public.notify_on_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_goal_title text;
  v_actor_name text;
begin
  if new.deleted_at is not null then
    return new;
  end if;

  if not public.is_group_goal(new.user_goal_id) then
    return new;
  end if;

  select ug.title into v_goal_title
  from public.user_goals ug
  where ug.id = new.user_goal_id;

  select coalesce(p.display_name, p.username, 'Someone')
  into v_actor_name
  from public.profiles p
  where p.id = new.author_id;

  perform public.notify_goal_members_except(
    new.user_goal_id,
    array[new.author_id],
    'group_post',
    'New group post',
    v_actor_name || ' posted in ' || coalesce(v_goal_title, 'a group goal'),
    jsonb_build_object(
      'log_id', new.id,
      'actor_id', new.author_id
    )
  );

  return new;
end;
$$;

drop trigger if exists logs_notify on public.logs;
create trigger logs_notify
  after insert on public.logs
  for each row execute function public.notify_on_log();

-- Reaction: notify log author + other group members.
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

  if v_author_id is null then
    return new;
  end if;

  select coalesce(p.display_name, p.username, 'Someone')
  into v_actor_name
  from public.profiles p
  where p.id = new.user_id;

  if v_author_id <> new.user_id then
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
  end if;

  perform public.notify_goal_members_except(
    v_goal_id,
    array[new.user_id, v_author_id],
    'group_reaction',
    'Group reaction',
    v_actor_name || ' reacted in ' || coalesce(v_goal_title, 'a group goal'),
    jsonb_build_object(
      'log_id', new.log_id,
      'actor_id', new.user_id,
      'emoji_type', new.emoji_type
    )
  );

  return new;
end;
$$;

-- Comment: notify log author + other group members.
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

  if v_author_id is null then
    return new;
  end if;

  select coalesce(p.display_name, p.username, 'Someone')
  into v_actor_name
  from public.profiles p
  where p.id = new.author_id;

  if v_author_id <> new.author_id then
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
  end if;

  perform public.notify_goal_members_except(
    v_goal_id,
    array[new.author_id, v_author_id],
    'group_comment',
    'Group comment',
    v_actor_name || ' commented in ' || coalesce(v_goal_title, 'a group goal'),
    jsonb_build_object(
      'log_id', new.log_id,
      'comment_id', new.id,
      'actor_id', new.author_id
    )
  );

  return new;
end;
$$;

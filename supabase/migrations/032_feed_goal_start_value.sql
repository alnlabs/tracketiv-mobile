-- Feed: include goal start_value for trend when no previous log exists.

drop function if exists public.get_my_feed(int);

create function public.get_my_feed(p_limit int default 50)
returns table (
  log_id uuid,
  created_at timestamptz,
  log_date date,
  log_value numeric,
  log_note text,
  author_id uuid,
  author_name text,
  author_username text,
  goal_id uuid,
  goal_title text,
  goal_mode text,
  metric_unit text,
  group_id uuid,
  group_name text,
  previous_log_value numeric,
  goal_start_value numeric,
  comment_count bigint
)
language sql
security definer
stable
set search_path = public
as $$
  select
    l.id as log_id,
    l.created_at,
    l.log_date,
    l.value as log_value,
    l.note as log_note,
    l.author_id,
    p.display_name as author_name,
    p.username as author_username,
    ug.id as goal_id,
    ug.title as goal_title,
    ug.mode as goal_mode,
    ug.metric_unit,
    ug.group_id,
    g.name as group_name,
    prev.value as previous_log_value,
    ug.start_value as goal_start_value,
    coalesce(cc.cnt, 0) as comment_count
  from public.logs l
  join public.user_goals ug on ug.id = l.user_goal_id
  left join public.groups g on g.id = ug.group_id
  join public.profiles p on p.id = l.author_id
  left join lateral (
    select pl.value
    from public.logs pl
    where pl.user_goal_id = l.user_goal_id
      and pl.author_id = l.author_id
      and pl.value is not null
      and pl.deleted_at is null
      and (pl.created_at, pl.id) < (l.created_at, l.id)
    order by pl.created_at desc, pl.id desc
    limit 1
  ) prev on true
  left join lateral (
    select count(*)::bigint as cnt
    from public.log_comments c
    where c.log_id = l.id
      and c.deleted_at is null
  ) cc on true
  where public.is_goal_member(ug.id)
    and ug.status = 'active'
    and l.deleted_at is null
    and ug.deleted_at is null
    and p.deleted_at is null
    and (g.id is null or g.deleted_at is null)
  order by l.created_at desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.get_my_feed(int) to authenticated;

drop function if exists public.get_feed_post(uuid);

create function public.get_feed_post(p_log_id uuid)
returns table (
  log_id uuid,
  created_at timestamptz,
  log_date date,
  log_value numeric,
  log_note text,
  author_id uuid,
  author_name text,
  author_username text,
  goal_id uuid,
  goal_title text,
  goal_mode text,
  metric_unit text,
  group_id uuid,
  group_name text,
  previous_log_value numeric,
  goal_start_value numeric,
  comment_count bigint
)
language sql
security definer
stable
set search_path = public
as $$
  select
    l.id as log_id,
    l.created_at,
    l.log_date,
    l.value as log_value,
    l.note as log_note,
    l.author_id,
    p.display_name as author_name,
    p.username as author_username,
    ug.id as goal_id,
    ug.title as goal_title,
    ug.mode as goal_mode,
    ug.metric_unit,
    ug.group_id,
    g.name as group_name,
    prev.value as previous_log_value,
    ug.start_value as goal_start_value,
    coalesce(cc.cnt, 0) as comment_count
  from public.logs l
  join public.user_goals ug on ug.id = l.user_goal_id
  left join public.groups g on g.id = ug.group_id
  join public.profiles p on p.id = l.author_id
  left join lateral (
    select pl.value
    from public.logs pl
    where pl.user_goal_id = l.user_goal_id
      and pl.author_id = l.author_id
      and pl.value is not null
      and pl.deleted_at is null
      and (pl.created_at, pl.id) < (l.created_at, l.id)
    order by pl.created_at desc, pl.id desc
    limit 1
  ) prev on true
  left join lateral (
    select count(*)::bigint as cnt
    from public.log_comments c
    where c.log_id = l.id
      and c.deleted_at is null
  ) cc on true
  where l.id = p_log_id
    and public.is_goal_member(ug.id)
    and ug.status = 'active'
    and l.deleted_at is null
    and ug.deleted_at is null
    and p.deleted_at is null
    and (g.id is null or g.deleted_at is null)
  limit 1;
$$;

grant execute on function public.get_feed_post(uuid) to authenticated;

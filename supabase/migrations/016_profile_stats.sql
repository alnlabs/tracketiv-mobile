-- Public profile stats based on goals a user follows (visible to any authenticated user)

create or replace function public.get_user_profile_stats(p_user_id uuid)
returns json
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_total_goals int;
  v_active_goals int;
  v_total_logs int;
  v_logs_this_week int;
  v_current_streak int;
  v_total_groups int;
  v_goals json;
begin
  if not exists (select 1 from public.profiles where id = p_user_id) then
    return null;
  end if;

  select count(*)::int
  into v_total_goals
  from public.goal_memberships gm
  where gm.user_id = p_user_id;

  select count(*)::int
  into v_active_goals
  from public.goal_memberships gm
  join public.user_goals ug on ug.id = gm.user_goal_id
  where gm.user_id = p_user_id
    and ug.status = 'active';

  select count(*)::int
  into v_total_logs
  from public.logs l
  where l.author_id = p_user_id;

  select count(*)::int
  into v_logs_this_week
  from public.logs l
  where l.author_id = p_user_id
    and l.log_date >= (current_date - 6);

  select count(*)::int
  into v_total_groups
  from public.group_memberships gm
  where gm.user_id = p_user_id;

  with log_days as (
    select distinct l.log_date::date as d
    from public.logs l
    where l.author_id = p_user_id
      and l.log_date::date <= current_date
  ),
  numbered as (
    select
      ld.d,
      ld.d - (row_number() over (order by ld.d desc))::int as grp
    from log_days ld
  ),
  anchor as (
    select n.grp
    from numbered n
    where n.d in (current_date, current_date - 1)
    order by n.d desc
    limit 1
  )
  select coalesce((
    select count(*)::int
    from numbered n
    join anchor a on n.grp = a.grp
  ), 0)
  into v_current_streak;

  select coalesce(
    json_agg(
      json_build_object(
        'goal_id', s.goal_id,
        'goal_title', s.goal_title,
        'goal_mode', s.goal_mode,
        'goal_cadence', s.goal_cadence,
        'goal_status', s.goal_status,
        'group_name', s.group_name,
        'log_count', s.log_count,
        'last_log_date', s.last_log_date,
        'last_log_at', s.last_log_at
      )
      order by s.last_log_at desc nulls last, s.goal_title
    ),
    '[]'::json
  )
  into v_goals
  from (
    select
      ug.id as goal_id,
      ug.title as goal_title,
      ug.mode as goal_mode,
      ug.cadence as goal_cadence,
      ug.status as goal_status,
      g.name as group_name,
      count(l.id)::int as log_count,
      max(l.log_date) as last_log_date,
      max(l.created_at) as last_log_at
    from public.goal_memberships gm
    join public.user_goals ug on ug.id = gm.user_goal_id
    left join public.groups g on g.id = ug.group_id
    left join public.logs l
      on l.user_goal_id = ug.id
     and l.author_id = p_user_id
    where gm.user_id = p_user_id
    group by ug.id, g.name
  ) s;

  if v_current_streak is null then
    v_current_streak := 0;
  end if;

  return json_build_object(
    'total_goals', v_total_goals,
    'active_goals', v_active_goals,
    'total_logs', v_total_logs,
    'logs_this_week', v_logs_this_week,
    'current_streak', v_current_streak,
    'total_groups', v_total_groups,
    'goals', v_goals
  );
end;
$$;

grant execute on function public.get_user_profile_stats(uuid) to authenticated;

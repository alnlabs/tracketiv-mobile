-- Allow owners to update solo (self) goals

create or replace function public.update_user_goal(p_goal_id uuid, p_goal jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_goal public.user_goals;
  v_cadence text := coalesce(nullif(p_goal->>'cadence', ''), 'daily');
  v_interval_days integer := nullif(p_goal->>'cadence_interval_days', '')::integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_goal from public.user_goals where id = p_goal_id;
  if not found then
    raise exception 'Goal not found';
  end if;

  if v_goal.mode != 'solo' or v_goal.group_id is not null then
    raise exception 'Only solo goals can be edited';
  end if;

  if not public.is_goal_owner(p_goal_id) then
    raise exception 'Only the goal owner can edit this goal';
  end if;

  if v_cadence not in ('daily', 'weekly', 'monthly', 'custom') then
    raise exception 'Invalid cadence';
  end if;

  if v_cadence = 'custom' and (v_interval_days is null or v_interval_days < 1) then
    raise exception 'Custom cadence requires interval days';
  end if;

  if v_cadence != 'custom' then
    v_interval_days := null;
  end if;

  update public.user_goals
  set
    title = coalesce(nullif(trim(p_goal->>'title'), ''), title),
    description = nullif(p_goal->>'description', ''),
    cadence = v_cadence,
    cadence_interval_days = v_interval_days,
    target_value = nullif(p_goal->>'target_value', '')::numeric,
    start_value = nullif(p_goal->>'start_value', '')::numeric,
    target_date = nullif(p_goal->>'target_date', '')::date,
    status = coalesce(nullif(p_goal->>'status', ''), status)
  where id = p_goal_id
  returning * into v_goal;

  return to_jsonb(v_goal);
end;
$$;

grant execute on function public.update_user_goal(uuid, jsonb) to authenticated;

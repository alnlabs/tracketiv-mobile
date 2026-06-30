-- Custom tracking interval (days between logs when cadence = 'custom')

alter table public.user_goals
  add column if not exists cadence_interval_days integer
  check (cadence_interval_days is null or cadence_interval_days > 0);

comment on column public.user_goals.cadence_interval_days is
  'Days between check-ins when cadence is custom (e.g. every 3 days)';

create or replace function public.create_user_goal(p_goal jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_goal public.user_goals;
  v_group_id uuid := nullif(p_goal->>'group_id', '')::uuid;
  v_cadence text := coalesce(nullif(p_goal->>'cadence', ''), 'daily');
  v_interval_days integer := nullif(p_goal->>'cadence_interval_days', '')::integer;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
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

  if v_group_id is not null and not (
    public.is_group_member(v_group_id)
    or exists (
      select 1 from public.groups g
      where g.id = v_group_id and g.owner_id = auth.uid()
    )
  ) then
    raise exception 'Not a member of this group';
  end if;

  insert into public.user_goals (
    template_id,
    owner_id,
    title,
    description,
    mode,
    cadence,
    cadence_interval_days,
    metric_type,
    metric_unit,
    target_value,
    start_value,
    target_date,
    group_id,
    status
  ) values (
    nullif(p_goal->>'template_id', '')::uuid,
    auth.uid(),
    p_goal->>'title',
    nullif(p_goal->>'description', ''),
    coalesce(nullif(p_goal->>'mode', ''), 'solo'),
    v_cadence,
    v_interval_days,
    p_goal->>'metric_type',
    nullif(p_goal->>'metric_unit', ''),
    nullif(p_goal->>'target_value', '')::numeric,
    nullif(p_goal->>'start_value', '')::numeric,
    nullif(p_goal->>'target_date', '')::date,
    v_group_id,
    coalesce(nullif(p_goal->>'status', ''), 'active')
  )
  returning * into v_goal;

  return to_jsonb(v_goal);
end;
$$;

grant execute on function public.create_user_goal(jsonb) to authenticated;

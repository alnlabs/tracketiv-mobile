-- Safe to run when user_goals already exists (does NOT create tables).
-- Run after 012_groups_rls_fix.sql.

drop policy if exists "Members can view their goals" on public.user_goals;

create policy "Members can view their goals"
  on public.user_goals for select
  to authenticated
  using (public.is_goal_member(id) or owner_id = auth.uid());

drop policy if exists "Users can create goals" on public.user_goals;

create policy "Users can create goals"
  on public.user_goals for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and (
      group_id is null
      or public.is_group_member(group_id)
      or exists (
        select 1 from public.groups g
        where g.id = group_id and g.owner_id = auth.uid()
      )
    )
  );

-- Create goal server-side (owner from auth.uid())
create or replace function public.create_user_goal(p_goal jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_goal public.user_goals;
  v_group_id uuid := nullif(p_goal->>'group_id', '')::uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
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
    p_goal->>'cadence',
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

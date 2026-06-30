-- Fix: goal_member_user_ids() returns setof uuid, not rows with user_id.
-- notify_goal_members_except used gmu.user_id which fails on group-goal log insert.

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

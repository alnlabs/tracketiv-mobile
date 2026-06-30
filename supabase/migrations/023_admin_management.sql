-- Admin management RPCs for the admin-only console

create or replace function public.admin_get_dashboard()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.is_app_admin() then
    raise exception 'Admin access required';
  end if;

  select jsonb_build_object(
    'users_total', (select count(*)::int from public.profiles where deleted_at is null),
    'users_deleted', (select count(*)::int from public.profiles where deleted_at is not null),
    'templates_total', (select count(*)::int from public.goal_templates where deleted_at is null),
    'templates_deleted', (select count(*)::int from public.goal_templates where deleted_at is not null),
    'feedback_total', (select count(*)::int from public.feedback where deleted_at is null),
    'feedback_open', (
      select count(*)::int
      from public.feedback
      where deleted_at is null
    ),
    'goals_total', (select count(*)::int from public.user_goals where deleted_at is null),
    'groups_total', (select count(*)::int from public.groups where deleted_at is null)
  )
  into v_result;

  return v_result;
end;
$$;

create or replace function public.admin_list_users(
  p_include_deleted boolean default false,
  p_limit int default 100
)
returns table (
  id uuid,
  email text,
  display_name text,
  username text,
  is_admin boolean,
  is_system_admin boolean,
  deleted_at timestamptz,
  created_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    p.id,
    u.email,
    p.display_name,
    p.username,
    p.is_admin,
    p.is_system_admin,
    p.deleted_at,
    p.created_at
  from public.profiles p
  join auth.users u on u.id = p.id
  where public.is_app_admin()
    and (p_include_deleted or p.deleted_at is null)
  order by p.created_at desc
  limit greatest(p_limit, 1);
$$;

create or replace function public.admin_get_app_config()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_settings jsonb;
begin
  if not public.is_app_admin() then
    raise exception 'Admin access required';
  end if;

  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  into v_settings
  from public.app_settings;

  return jsonb_build_object(
    'settings', v_settings,
    'system_admin_email', public.get_system_admin_email()
  );
end;
$$;

grant execute on function public.admin_get_dashboard() to authenticated;
grant execute on function public.admin_list_users(boolean, int) to authenticated;
grant execute on function public.admin_get_app_config() to authenticated;

-- Custom in-app crash / error reports

create table public.crash_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  message text not null,
  stack_trace text,
  error_type text not null default 'unknown',
  platform text,
  app_version text,
  route text,
  is_admin_mode boolean not null default false,
  context jsonb not null default '{}'::jsonb,
  created_at timestamptz default now() not null
);

create index crash_reports_created_at_idx on public.crash_reports (created_at desc);
create index crash_reports_user_id_idx on public.crash_reports (user_id);

alter table public.crash_reports enable row level security;

create policy "Admins can view crash reports"
  on public.crash_reports for select
  to authenticated
  using (public.is_app_admin());

create or replace function public.submit_crash_report(p_report jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_message text := trim(coalesce(p_report->>'message', ''));
begin
  if char_length(v_message) < 1 then
    raise exception 'Crash message is required';
  end if;

  insert into public.crash_reports (
    user_id,
    message,
    stack_trace,
    error_type,
    platform,
    app_version,
    route,
    is_admin_mode,
    context
  ) values (
    auth.uid(),
    left(v_message, 2000),
    left(nullif(p_report->>'stack_trace', ''), 12000),
    coalesce(nullif(p_report->>'error_type', ''), 'unknown'),
    nullif(p_report->>'platform', ''),
    nullif(p_report->>'app_version', ''),
    nullif(p_report->>'route', ''),
    coalesce((p_report->>'is_admin_mode')::boolean, false),
    coalesce(p_report->'context', '{}'::jsonb)
  )
  returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.admin_list_crash_reports(p_limit int default 100)
returns table (
  id uuid,
  user_id uuid,
  message text,
  stack_trace text,
  error_type text,
  platform text,
  app_version text,
  route text,
  is_admin_mode boolean,
  created_at timestamptz,
  user_email text,
  user_name text
)
language sql
security definer
stable
set search_path = public
as $$
  select
    c.id,
    c.user_id,
    c.message,
    c.stack_trace,
    c.error_type,
    c.platform,
    c.app_version,
    c.route,
    c.is_admin_mode,
    c.created_at,
    u.email,
    p.display_name
  from public.crash_reports c
  left join auth.users u on u.id = c.user_id
  left join public.profiles p on p.id = c.user_id
  where public.is_app_admin()
  order by c.created_at desc
  limit greatest(p_limit, 1);
$$;

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
    'feedback_open', (select count(*)::int from public.feedback where deleted_at is null),
    'goals_total', (select count(*)::int from public.user_goals where deleted_at is null),
    'groups_total', (select count(*)::int from public.groups where deleted_at is null),
    'crashes_total', (select count(*)::int from public.crash_reports),
    'crashes_24h', (
      select count(*)::int
      from public.crash_reports
      where created_at >= now() - interval '24 hours'
    )
  )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.submit_crash_report(jsonb) to anon, authenticated;
grant execute on function public.admin_list_crash_reports(int) to authenticated;

-- Feed: recent logs from all goals the user can access

create or replace function public.get_my_feed(p_limit int default 50)
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
  group_name text
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
    g.name as group_name
  from public.logs l
  join public.user_goals ug on ug.id = l.user_goal_id
  left join public.groups g on g.id = ug.group_id
  join public.profiles p on p.id = l.author_id
  where public.is_goal_member(ug.id)
    and ug.status = 'active'
  order by l.created_at desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.get_my_feed(int) to authenticated;

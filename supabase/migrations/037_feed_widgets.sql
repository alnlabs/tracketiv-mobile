-- Configurable feed widgets (quote first). Owners/users set schedule; appearances merge into get_my_feed.

create table public.feed_quote_pool (
  id serial primary key,
  text text not null,
  author text not null,
  category text not null default 'goal'
    check (category in ('goal', 'life', 'community'))
);

insert into public.feed_quote_pool (text, author, category) values
  ('Small steps every day add up to big change.', 'Tracketiv', 'goal'),
  ('Discipline is choosing between what you want now and what you want most.', 'Abraham Lincoln', 'goal'),
  ('Alone we can do so little; together we can do so much.', 'Helen Keller', 'community'),
  ('The secret of getting ahead is getting started.', 'Mark Twain', 'goal'),
  ('Happiness is not something ready made. It comes from your own actions.', 'Dalai Lama', 'life'),
  ('Success is the sum of small efforts, repeated day in and day out.', 'Robert Collier', 'goal'),
  ('A journey of a thousand miles begins with a single step.', 'Lao Tzu', 'life'),
  ('Teamwork makes the dream work.', 'John C. Maxwell', 'community'),
  ('What you get by achieving your goals is not as important as what you become.', 'Zig Ziglar', 'goal'),
  ('The best time to plant a tree was 20 years ago. The second best time is now.', 'Chinese Proverb', 'life');

create table public.feed_widgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  group_id uuid references public.groups(id) on delete cascade,
  widget_type text not null default 'quote'
    check (widget_type in ('quote')),
  enabled boolean not null default true,
  show_time time not null default '06:00',
  timezone text not null default 'UTC',
  config jsonb not null default '{}'::jsonb,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.profiles(id),
  check (
    (user_id is not null and group_id is null)
    or (user_id is null and group_id is not null)
  )
);

create unique index feed_widgets_user_quote_active_idx
  on public.feed_widgets (user_id, widget_type)
  where user_id is not null and group_id is null and deleted_at is null;

create unique index feed_widgets_group_quote_active_idx
  on public.feed_widgets (group_id, widget_type)
  where group_id is not null and user_id is null and deleted_at is null;

create table public.feed_widget_appearances (
  id uuid primary key default gen_random_uuid(),
  widget_id uuid not null references public.feed_widgets(id) on delete cascade,
  slot_date date not null,
  created_at timestamptz not null,
  content jsonb not null,
  unique (widget_id, slot_date)
);

create index feed_widget_appearances_created_at_idx
  on public.feed_widget_appearances (created_at desc);

alter table public.feed_widgets enable row level security;
alter table public.feed_widget_appearances enable row level security;
alter table public.feed_quote_pool enable row level security;

create policy "Anyone can read quote pool"
  on public.feed_quote_pool for select
  to authenticated
  using (true);

create policy "Users read own personal widgets"
  on public.feed_widgets for select
  to authenticated
  using (user_id = auth.uid() and deleted_at is null);

create policy "Group members read group widgets"
  on public.feed_widgets for select
  to authenticated
  using (group_id is not null and public.is_group_member(group_id) and deleted_at is null);

create policy "Users read visible widget appearances"
  on public.feed_widget_appearances for select
  to authenticated
  using (
    exists (
      select 1 from public.feed_widgets w
      where w.id = widget_id
        and w.deleted_at is null
        and w.enabled
        and (
          w.user_id = auth.uid()
          or (w.group_id is not null and public.is_group_member(w.group_id))
        )
    )
  );

create trigger feed_widgets_updated_at
  before update on public.feed_widgets
  for each row execute function public.handle_updated_at();

create or replace function public.resolve_feed_widget_quote_content(
  p_widget_id uuid,
  p_slot_date date,
  p_config jsonb
)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_source text;
  v_text text;
  v_author text;
  v_category text;
  v_pool_count int;
  v_offset int;
  v_row record;
begin
  v_source := coalesce(p_config->>'source', 'pool');

  if v_source = 'custom' then
    v_text := nullif(trim(p_config->>'text'), '');
    v_author := nullif(trim(p_config->>'author'), '');
    v_category := coalesce(nullif(p_config->>'category', ''), 'goal');
    if v_text is not null then
      return jsonb_build_object(
        'text', v_text,
        'author', coalesce(v_author, 'Tracketiv'),
        'category', v_category
      );
    end if;
  end if;

  select count(*)::int into v_pool_count from public.feed_quote_pool;
  if v_pool_count = 0 then
    return jsonb_build_object(
      'text', 'Small steps every day add up to big change.',
      'author', 'Tracketiv',
      'category', 'goal'
    );
  end if;

  v_offset := abs(hashtext(p_widget_id::text || p_slot_date::text)) % v_pool_count;

  select text, author, category
  into v_row
  from public.feed_quote_pool
  order by id
  offset v_offset
  limit 1;

  return jsonb_build_object(
    'text', v_row.text,
    'author', v_row.author,
    'category', v_row.category
  );
end;
$$;

create or replace function public.materialize_feed_widget_appearances()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_slot_date date;
  v_created_at timestamptz;
  v_content jsonb;
begin
  for r in
    select *
    from public.feed_widgets
    where enabled
      and deleted_at is null
  loop
    v_slot_date := (now() at time zone r.timezone)::date;
    v_created_at := (v_slot_date::timestamp + r.show_time) at time zone r.timezone;

    if now() < v_created_at then
      continue;
    end if;

    v_content := public.resolve_feed_widget_quote_content(r.id, v_slot_date, r.config);

    insert into public.feed_widget_appearances (widget_id, slot_date, created_at, content)
    values (r.id, v_slot_date, v_created_at, v_content)
    on conflict (widget_id, slot_date) do nothing;
  end loop;
end;
$$;

create or replace function public.upsert_feed_widget(
  p_widget_id uuid default null,
  p_user_id uuid default null,
  p_group_id uuid default null,
  p_widget_type text default 'quote',
  p_enabled boolean default true,
  p_show_time time default '06:00',
  p_timezone text default 'UTC',
  p_config jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_widget_type <> 'quote' then
    raise exception 'Unsupported widget type';
  end if;

  if p_user_id is not null and p_group_id is not null then
    raise exception 'Widget must be personal or group scoped, not both';
  end if;

  if p_user_id is null and p_group_id is null then
    raise exception 'Widget must be personal or group scoped';
  end if;

  if p_user_id is not null then
    if p_user_id <> v_uid then
      raise exception 'Cannot manage another user''s personal widget';
    end if;
  end if;

  if p_group_id is not null and not public.is_group_owner(p_group_id) then
    raise exception 'Only group owners can manage group feed widgets';
  end if;

  if p_widget_id is null then
    insert into public.feed_widgets (
      user_id, group_id, widget_type, enabled, show_time, timezone, config, created_by
    ) values (
      p_user_id, p_group_id, p_widget_type, p_enabled, p_show_time, p_timezone, p_config, v_uid
    )
    returning id into v_id;
    return v_id;
  end if;

  update public.feed_widgets
  set
    enabled = p_enabled,
    show_time = p_show_time,
    timezone = p_timezone,
    config = p_config,
    updated_at = now()
  where id = p_widget_id
    and deleted_at is null
    and (
      (user_id = v_uid and p_user_id = v_uid)
      or (group_id is not null and p_group_id = group_id and public.is_group_owner(group_id))
    )
  returning id into v_id;

  if v_id is null then
    raise exception 'Widget not found or not permitted';
  end if;

  return v_id;
end;
$$;

create or replace function public.list_my_feed_widgets()
returns table (
  id uuid,
  user_id uuid,
  group_id uuid,
  group_name text,
  widget_type text,
  enabled boolean,
  show_time time,
  timezone text,
  config jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    w.id,
    w.user_id,
    w.group_id,
    g.name as group_name,
    w.widget_type,
    w.enabled,
    w.show_time,
    w.timezone,
    w.config,
    w.created_at,
    w.updated_at
  from public.feed_widgets w
  left join public.groups g on g.id = w.group_id and g.deleted_at is null
  where w.deleted_at is null
    and (
      w.user_id = auth.uid()
      or (w.group_id is not null and public.is_group_owner(w.group_id))
    )
  order by w.created_at desc;
$$;

grant execute on function public.materialize_feed_widget_appearances() to authenticated;
grant execute on function public.upsert_feed_widget(uuid, uuid, uuid, text, boolean, time, text, jsonb) to authenticated;
grant execute on function public.list_my_feed_widgets() to authenticated;

-- Extend feed RPC: logs + widget appearances in chronological order.

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
  metric_type text,
  metric_unit text,
  group_id uuid,
  group_name text,
  previous_log_value numeric,
  goal_start_value numeric,
  comment_count bigint,
  item_type text,
  widget_type text,
  widget_payload jsonb,
  widget_user_id uuid
)
language plpgsql
security definer
stable
set search_path = public
as $$
begin
  perform public.materialize_feed_widget_appearances();

  return query
  select *
  from (
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
      ug.metric_type,
      ug.metric_unit,
      ug.group_id,
      g.name as group_name,
      prev.value as previous_log_value,
      ug.start_value as goal_start_value,
      coalesce(cc.cnt, 0) as comment_count,
      'log'::text as item_type,
      null::text as widget_type,
      null::jsonb as widget_payload,
      null::uuid as widget_user_id
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

    union all

    select
      a.id as log_id,
      a.created_at,
      a.slot_date as log_date,
      null::numeric as log_value,
      null::text as log_note,
      null::uuid as author_id,
      'Tracketiv'::text as author_name,
      null::text as author_username,
      null::uuid as goal_id,
      case
        when w.group_id is not null then coalesce(g.name, 'Group') || ' · Daily quote'
        else 'Daily quote'
      end as goal_title,
      case when w.group_id is not null then 'group' else 'solo' end as goal_mode,
      null::text as metric_type,
      null::text as metric_unit,
      w.group_id,
      g.name as group_name,
      null::numeric as previous_log_value,
      null::numeric as goal_start_value,
      0::bigint as comment_count,
      'widget'::text as item_type,
      w.widget_type,
      a.content as widget_payload,
      w.user_id as widget_user_id
    from public.feed_widget_appearances a
    join public.feed_widgets w on w.id = a.widget_id
    left join public.groups g on g.id = w.group_id and g.deleted_at is null
    where w.deleted_at is null
      and w.enabled
      and (
        w.user_id = auth.uid()
        or (w.group_id is not null and public.is_group_member(w.group_id))
      )
  ) combined
  order by combined.created_at desc
  limit greatest(p_limit, 1);
end;
$$;

grant execute on function public.get_my_feed(int) to authenticated;

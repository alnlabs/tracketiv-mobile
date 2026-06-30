-- Mutual friend connections: request/accept, feed visibility, social access.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id)
);

create unique index friend_requests_pending_pair_idx
  on public.friend_requests (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  )
  where status = 'pending';

create index friend_requests_addressee_pending_idx
  on public.friend_requests (addressee_id)
  where status = 'pending';

create table public.friendships (
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

create index friendships_friend_id_idx on public.friendships (friend_id);

alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;

create policy "Users read own friend requests"
  on public.friend_requests for select
  to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());

create policy "Users read own friendships"
  on public.friendships for select
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.are_friends(p_user_a uuid, p_user_b uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select p_user_a is not null
    and p_user_b is not null
    and p_user_a <> p_user_b
    and exists (
      select 1
      from public.friendships f
      where f.user_id = p_user_a
        and f.friend_id = p_user_b
    );
$$;

create or replace function public.is_friend_of(p_user_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select public.are_friends(auth.uid(), p_user_id);
$$;

create or replace function public.can_view_log(p_log_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.logs l
    join public.user_goals ug on ug.id = l.user_goal_id
    where l.id = p_log_id
      and l.deleted_at is null
      and ug.deleted_at is null
      and ug.status = 'active'
      and (
        public.is_goal_member(ug.id)
        or public.is_friend_of(l.author_id)
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Notification types
-- ---------------------------------------------------------------------------

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
    'group_invite',
    'goal_invite',
    'reaction',
    'comment',
    'group_post',
    'group_reaction',
    'group_comment',
    'friend_request',
    'friend_accepted'
  ));

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

create or replace function public.send_friend_request(p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_request_id uuid;
  v_name text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_user_id is null or p_user_id = v_uid then
    raise exception 'Invalid user';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = p_user_id and p.deleted_at is null
  ) then
    raise exception 'User not found';
  end if;

  if public.are_friends(v_uid, p_user_id) then
    raise exception 'Already friends';
  end if;

  if exists (
    select 1
    from public.friend_requests fr
    where fr.status = 'pending'
      and (
        (fr.requester_id = v_uid and fr.addressee_id = p_user_id)
        or (fr.requester_id = p_user_id and fr.addressee_id = v_uid)
      )
  ) then
    raise exception 'Friend request already pending';
  end if;

  insert into public.friend_requests (requester_id, addressee_id, status)
  values (v_uid, p_user_id, 'pending')
  returning id into v_request_id;

  select coalesce(p.display_name, p.username, 'Someone')
  into v_name
  from public.profiles p
  where p.id = v_uid;

  perform public.create_notification(
    p_user_id,
    'friend_request',
    'Friend request',
    v_name || ' wants to connect',
    jsonb_build_object(
      'request_id', v_request_id,
      'actor_id', v_uid
    )
  );

  return v_request_id;
end;
$$;

create or replace function public.respond_friend_request(
  p_request_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_request public.friend_requests%rowtype;
  v_name text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_request
  from public.friend_requests fr
  where fr.id = p_request_id
    and fr.status = 'pending'
  for update;

  if not found then
    raise exception 'Friend request not found';
  end if;

  if p_accept then
    if v_request.addressee_id <> v_uid then
      raise exception 'Only the recipient can accept';
    end if;

    update public.friend_requests
    set status = 'accepted', responded_at = now()
    where id = p_request_id;

    insert into public.friendships (user_id, friend_id)
    values
      (v_request.requester_id, v_request.addressee_id),
      (v_request.addressee_id, v_request.requester_id)
    on conflict do nothing;

    select coalesce(p.display_name, p.username, 'Someone')
    into v_name
    from public.profiles p
    where p.id = v_uid;

    perform public.create_notification(
      v_request.requester_id,
      'friend_accepted',
      'Friend request accepted',
      v_name || ' accepted your friend request',
      jsonb_build_object(
        'actor_id', v_uid,
        'friend_id', v_uid
      )
    );
  else
    if v_request.addressee_id = v_uid then
      update public.friend_requests
      set status = 'declined', responded_at = now()
      where id = p_request_id;
    elsif v_request.requester_id = v_uid then
      update public.friend_requests
      set status = 'cancelled', responded_at = now()
      where id = p_request_id;
    else
      raise exception 'Not permitted';
    end if;
  end if;
end;
$$;

create or replace function public.remove_friend(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.friendships
  where (user_id = v_uid and friend_id = p_user_id)
     or (user_id = p_user_id and friend_id = v_uid);
end;
$$;

create or replace function public.list_my_friends()
returns table (
  friend_id uuid,
  display_name text,
  username text,
  friends_since timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    f.friend_id,
    p.display_name,
    p.username,
    f.created_at as friends_since
  from public.friendships f
  join public.profiles p on p.id = f.friend_id and p.deleted_at is null
  where f.user_id = auth.uid()
  order by f.created_at desc;
$$;

create or replace function public.list_friend_requests()
returns table (
  id uuid,
  requester_id uuid,
  addressee_id uuid,
  requester_name text,
  requester_username text,
  addressee_name text,
  addressee_username text,
  direction text,
  created_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    fr.id,
    fr.requester_id,
    fr.addressee_id,
    rp.display_name as requester_name,
    rp.username as requester_username,
    ap.display_name as addressee_name,
    ap.username as addressee_username,
    case
      when fr.addressee_id = auth.uid() then 'incoming'
      else 'outgoing'
    end as direction,
    fr.created_at
  from public.friend_requests fr
  join public.profiles rp on rp.id = fr.requester_id
  join public.profiles ap on ap.id = fr.addressee_id
  where fr.status = 'pending'
    and (fr.requester_id = auth.uid() or fr.addressee_id = auth.uid())
  order by fr.created_at desc;
$$;

create or replace function public.get_friendship_status(p_user_id uuid)
returns text
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return 'none';
  end if;

  if p_user_id is null or p_user_id = v_uid then
    return 'self';
  end if;

  if public.are_friends(v_uid, p_user_id) then
    return 'friends';
  end if;

  if exists (
    select 1 from public.friend_requests fr
    where fr.status = 'pending'
      and fr.requester_id = v_uid
      and fr.addressee_id = p_user_id
  ) then
    return 'pending_outgoing';
  end if;

  if exists (
    select 1 from public.friend_requests fr
    where fr.status = 'pending'
      and fr.requester_id = p_user_id
      and fr.addressee_id = v_uid
  ) then
    return 'pending_incoming';
  end if;

  return 'none';
end;
$$;

grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.is_friend_of(uuid) to authenticated;
grant execute on function public.can_view_log(uuid) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.list_my_friends() to authenticated;
grant execute on function public.list_friend_requests() to authenticated;
grant execute on function public.get_friendship_status(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Social RLS: friends can view/react/comment on visible logs
-- ---------------------------------------------------------------------------

drop policy if exists "Members can view comments on goal logs" on public.log_comments;
drop policy if exists "Members can add comments" on public.log_comments;
drop policy if exists "Members can view reactions" on public.log_reactions;
drop policy if exists "Members can add reactions" on public.log_reactions;

create policy "Viewers can read comments on visible logs"
  on public.log_comments for select
  to authenticated
  using (public.can_view_log(log_id));

create policy "Viewers can add comments on visible logs"
  on public.log_comments for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and public.can_view_log(log_id)
  );

create policy "Viewers can read reactions on visible logs"
  on public.log_reactions for select
  to authenticated
  using (public.can_view_log(log_id));

create policy "Viewers can add reactions on visible logs"
  on public.log_reactions for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.can_view_log(log_id)
  );

-- ---------------------------------------------------------------------------
-- Feed RPCs: include friend-authored logs
-- ---------------------------------------------------------------------------

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
    where (
        public.is_goal_member(ug.id)
        or public.is_friend_of(l.author_id)
      )
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
  where l.id = p_log_id
    and public.can_view_log(l.id)
    and ug.status = 'active'
    and l.deleted_at is null
    and ug.deleted_at is null
    and p.deleted_at is null
    and (g.id is null or g.deleted_at is null)
  limit 1;
$$;

grant execute on function public.get_feed_post(uuid) to authenticated;

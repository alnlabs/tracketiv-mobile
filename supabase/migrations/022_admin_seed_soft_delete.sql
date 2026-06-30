-- Protected system admin seed + soft delete across app data

-- ---------------------------------------------------------------------------
-- Immutable app settings (system admin email cannot be changed in-app)
-- ---------------------------------------------------------------------------

create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  created_at timestamptz default now() not null
);

insert into public.app_settings (key, value)
values ('system_admin_email', 'alnlabs.com@gmail.com')
on conflict (key) do nothing;

alter table public.app_settings enable row level security;

create policy "Authenticated users can read app settings"
  on public.app_settings for select
  to authenticated
  using (true);

create or replace function public.protect_app_settings()
returns trigger
language plpgsql
as $$
begin
  raise exception 'App settings cannot be modified';
end;
$$;

drop trigger if exists protect_app_settings_trigger on public.app_settings;
create trigger protect_app_settings_trigger
  before update or delete on public.app_settings
  for each row execute function public.protect_app_settings();

-- ---------------------------------------------------------------------------
-- System admin flags on profiles (includes 021 admin prerequisites)
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists is_admin boolean not null default false;

alter table public.profiles
  add column if not exists is_system_admin boolean not null default false;

alter table public.profiles
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.goal_templates
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.user_goals
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.goal_memberships
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.logs
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.log_comments
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.log_reactions
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.reminders
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.goal_invites
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.groups
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.group_memberships
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.group_invites
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.notifications
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.feedback
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

create index if not exists profiles_deleted_at_idx on public.profiles (deleted_at);
create index if not exists goal_templates_deleted_at_idx on public.goal_templates (deleted_at);
create index if not exists user_goals_deleted_at_idx on public.user_goals (deleted_at);
create index if not exists logs_deleted_at_idx on public.logs (deleted_at);
create index if not exists groups_deleted_at_idx on public.groups (deleted_at);
create index if not exists feedback_deleted_at_idx on public.feedback (deleted_at);

create or replace function public.is_app_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (
      select p.is_admin
      from public.profiles p
      where p.id = auth.uid()
        and p.deleted_at is null
    ),
    false
  );
$$;

-- Admin policies from 021 (idempotent)
drop policy if exists "Admins can insert goal templates" on public.goal_templates;
create policy "Admins can insert goal templates"
  on public.goal_templates for insert
  to authenticated
  with check (public.is_app_admin());

drop policy if exists "Admins can update goal templates" on public.goal_templates;
create policy "Admins can update goal templates"
  on public.goal_templates for update
  to authenticated
  using (public.is_app_admin());

drop policy if exists "Admins can delete goal templates" on public.goal_templates;
create policy "Admins can delete goal templates"
  on public.goal_templates for delete
  to authenticated
  using (public.is_app_admin());

drop policy if exists "Admins can view all feedback" on public.feedback;
create policy "Admins can view all feedback"
  on public.feedback for select
  to authenticated
  using (public.is_app_admin());

create or replace function public.get_system_admin_email()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select value from public.app_settings where key = 'system_admin_email' limit 1;
$$;

create or replace function public.apply_system_admin_flags(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_admin_email text;
begin
  select email into v_email from auth.users where id = p_user_id;
  v_admin_email := public.get_system_admin_email();

  if v_email is not null
     and v_admin_email is not null
     and lower(v_email) = lower(v_admin_email) then
    update public.profiles
    set is_admin = true,
        is_system_admin = true,
        deleted_at = null,
        deleted_by = null
    where id = p_user_id;
  end if;
end;
$$;

create or replace function public.protect_system_admin()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' and old.is_system_admin then
    raise exception 'System admin account cannot be deleted';
  end if;

  if tg_op = 'UPDATE' then
    if old.is_system_admin then
      if new.is_system_admin is distinct from true then
        raise exception 'System admin flag cannot be removed';
      end if;
      if new.is_admin is distinct from true then
        raise exception 'System admin privileges cannot be revoked';
      end if;
      if new.deleted_at is not null then
        raise exception 'System admin cannot be soft-deleted';
      end if;
    elsif new.is_system_admin is distinct from old.is_system_admin
          and new.is_system_admin = true then
      if not exists (
        select 1
        from auth.users u
        where u.id = new.id
          and lower(u.email) = lower(public.get_system_admin_email())
      ) then
        raise exception 'Cannot promote user to system admin';
      end if;
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists protect_system_admin_trigger on public.profiles;
create trigger protect_system_admin_trigger
  before update or delete on public.profiles
  for each row execute function public.protect_system_admin();

-- Promote configured email on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text := lower(trim(new.raw_user_meta_data->>'username'));
  v_display_name text := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    v_username,
    split_part(new.email, '@', 1)
  );
begin
  insert into public.profiles (id, display_name, username)
  values (new.id, v_display_name, nullif(v_username, ''));

  perform public.apply_system_admin_flags(new.id);

  insert into public.goal_memberships (user_goal_id, user_id, role)
  select gi.user_goal_id, new.id, 'member'
  from public.goal_invites gi
  where lower(gi.invited_email) = lower(new.email)
    and gi.status = 'pending'
    and gi.deleted_at is null
  on conflict (user_goal_id, user_id) do nothing;

  update public.goal_invites
  set status = 'accepted'
  where lower(invited_email) = lower(new.email)
    and status = 'pending'
    and deleted_at is null;

  insert into public.group_memberships (group_id, user_id, role)
  select gi.group_id, new.id, 'member'
  from public.group_invites gi
  where lower(gi.invited_email) = lower(new.email)
    and gi.status = 'pending'
    and gi.deleted_at is null
  on conflict (group_id, user_id) do nothing;

  update public.group_invites
  set status = 'accepted'
  where lower(invited_email) = lower(new.email)
    and status = 'pending'
    and deleted_at is null;

  return new;
end;
$$;

-- Seed system admin for an existing account (if already registered)
do $$
declare
  v_user_id uuid;
begin
  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = lower(public.get_system_admin_email())
  limit 1;

  if v_user_id is not null then
    perform public.apply_system_admin_flags(v_user_id);
  end if;
end;
$$;

create or replace function public.is_app_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce(
    (
      select p.is_admin
      from public.profiles p
      where p.id = auth.uid()
        and p.deleted_at is null
    ),
    false
  );
$$;

-- ---------------------------------------------------------------------------
-- Convert hard deletes into soft deletes
-- ---------------------------------------------------------------------------

create or replace function public.convert_delete_to_soft_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  execute format(
    'update %I.%I set deleted_at = now(), deleted_by = $1 where id = $2 and deleted_at is null',
    tg_table_schema,
    tg_table_name
  )
  using auth.uid(), old.id;

  return null;
end;
$$;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'profiles',
    'goal_templates',
    'user_goals',
    'goal_memberships',
    'logs',
    'log_comments',
    'log_reactions',
    'reminders',
    'goal_invites',
    'groups',
    'group_memberships',
    'group_invites',
    'notifications',
    'feedback'
  ]
  loop
    execute format('drop trigger if exists soft_delete_%I on public.%I', v_table, v_table);
    execute format(
      'create trigger soft_delete_%I before delete on public.%I for each row execute function public.convert_delete_to_soft_delete()',
      v_table,
      v_table
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helper functions respect soft delete
-- ---------------------------------------------------------------------------

create or replace function public.get_log_goal_id(p_log_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select user_goal_id
  from public.logs
  where id = p_log_id
    and deleted_at is null;
$$;

create or replace function public.is_group_member(p_group_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.group_memberships gm
    join public.groups g on g.id = gm.group_id
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.deleted_at is null
      and g.deleted_at is null
  );
$$;

create or replace function public.is_group_owner(p_group_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.group_memberships gm
    join public.groups g on g.id = gm.group_id
    where gm.group_id = p_group_id
      and gm.user_id = auth.uid()
      and gm.role = 'owner'
      and gm.deleted_at is null
      and g.deleted_at is null
  );
$$;

create or replace function public.is_goal_member(goal_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.goal_memberships gm
    join public.user_goals ug on ug.id = gm.user_goal_id
    where gm.user_goal_id = goal_id
      and gm.user_id = auth.uid()
      and gm.deleted_at is null
      and ug.deleted_at is null
  )
  or exists (
    select 1
    from public.user_goals ug
    join public.group_memberships gm on gm.group_id = ug.group_id
    join public.groups g on g.id = ug.group_id
    where ug.id = goal_id
      and ug.group_id is not null
      and gm.user_id = auth.uid()
      and ug.deleted_at is null
      and gm.deleted_at is null
      and g.deleted_at is null
  );
$$;

create or replace function public.is_goal_owner(goal_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.goal_memberships gm
    join public.user_goals ug on ug.id = gm.user_goal_id
    where gm.user_goal_id = goal_id
      and gm.user_id = auth.uid()
      and gm.role = 'owner'
      and gm.deleted_at is null
      and ug.deleted_at is null
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS: hide soft-deleted rows from regular users; admins see everything
-- ---------------------------------------------------------------------------

drop policy if exists "Authenticated users can view goal templates" on public.goal_templates;
create policy "Authenticated users can view active goal templates"
  on public.goal_templates for select
  to authenticated
  using (deleted_at is null);

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own active profile"
  on public.profiles for select
  using (auth.uid() = id and deleted_at is null);

drop policy if exists "Users can view profiles of goal members" on public.profiles;
create policy "Users can view active profiles of goal members"
  on public.profiles for select
  using (
    deleted_at is null
    and exists (
      select 1
      from public.goal_memberships gm1
      join public.goal_memberships gm2 on gm1.user_goal_id = gm2.user_goal_id
      join public.user_goals ug on ug.id = gm1.user_goal_id
      where gm1.user_id = auth.uid()
        and gm2.user_id = profiles.id
        and gm1.deleted_at is null
        and gm2.deleted_at is null
        and ug.deleted_at is null
    )
  );

drop policy if exists "Users can view own feedback" on public.feedback;
create policy "Users can view own active feedback"
  on public.feedback for select
  to authenticated
  using (user_id = auth.uid() and deleted_at is null);

create policy "Admins can view all profiles"
  on public.profiles for select
  to authenticated
  using (public.is_app_admin());

create policy "Admins can view all goal templates including deleted"
  on public.goal_templates for select
  to authenticated
  using (public.is_app_admin());

create policy "Admins can view all user goals"
  on public.user_goals for select
  to authenticated
  using (public.is_app_admin());

create policy "Admins can view all logs"
  on public.logs for select
  to authenticated
  using (public.is_app_admin());

create policy "Admins can view all groups"
  on public.groups for select
  to authenticated
  using (public.is_app_admin());

create policy "Admins can view all feedback including deleted"
  on public.feedback for select
  to authenticated
  using (public.is_app_admin());

create policy "Admins can update all profiles"
  on public.profiles for update
  to authenticated
  using (public.is_app_admin());

create policy "Admins can update all user goals"
  on public.user_goals for update
  to authenticated
  using (public.is_app_admin());

create policy "Admins can update all logs"
  on public.logs for update
  to authenticated
  using (public.is_app_admin());

create policy "Admins can update all groups"
  on public.groups for update
  to authenticated
  using (public.is_app_admin());

create policy "Admins can update all feedback"
  on public.feedback for update
  to authenticated
  using (public.is_app_admin());

-- ---------------------------------------------------------------------------
-- Admin data control RPCs
-- ---------------------------------------------------------------------------

create or replace function public.admin_soft_delete(p_table text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception 'Admin access required';
  end if;

  case p_table
    when 'profiles' then
      if exists (select 1 from public.profiles where id = p_id and is_system_admin) then
        raise exception 'System admin cannot be deleted';
      end if;
      update public.profiles
      set deleted_at = now(), deleted_by = auth.uid()
      where id = p_id and deleted_at is null;
    when 'goal_templates' then
      update public.goal_templates
      set deleted_at = now(), deleted_by = auth.uid()
      where id = p_id and deleted_at is null;
    when 'user_goals' then
      update public.user_goals
      set deleted_at = now(), deleted_by = auth.uid()
      where id = p_id and deleted_at is null;
    when 'logs' then
      update public.logs
      set deleted_at = now(), deleted_by = auth.uid()
      where id = p_id and deleted_at is null;
    when 'groups' then
      update public.groups
      set deleted_at = now(), deleted_by = auth.uid()
      where id = p_id and deleted_at is null;
    when 'feedback' then
      update public.feedback
      set deleted_at = now(), deleted_by = auth.uid()
      where id = p_id and deleted_at is null;
    when 'notifications' then
      update public.notifications
      set deleted_at = now(), deleted_by = auth.uid()
      where id = p_id and deleted_at is null;
    else
      raise exception 'Unsupported table: %', p_table;
  end case;
end;
$$;

create or replace function public.admin_restore(p_table text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception 'Admin access required';
  end if;

  case p_table
    when 'profiles' then
      update public.profiles
      set deleted_at = null, deleted_by = null
      where id = p_id;
    when 'goal_templates' then
      update public.goal_templates
      set deleted_at = null, deleted_by = null
      where id = p_id;
    when 'user_goals' then
      update public.user_goals
      set deleted_at = null, deleted_by = null
      where id = p_id;
    when 'logs' then
      update public.logs
      set deleted_at = null, deleted_by = null
      where id = p_id;
    when 'groups' then
      update public.groups
      set deleted_at = null, deleted_by = null
      where id = p_id;
    when 'feedback' then
      update public.feedback
      set deleted_at = null, deleted_by = null
      where id = p_id;
    when 'notifications' then
      update public.notifications
      set deleted_at = null, deleted_by = null
      where id = p_id;
    else
      raise exception 'Unsupported table: %', p_table;
  end case;
end;
$$;

create or replace function public.admin_list_records(
  p_table text,
  p_include_deleted boolean default false,
  p_limit int default 100
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_rows jsonb;
begin
  if not public.is_app_admin() then
    raise exception 'Admin access required';
  end if;

  case p_table
    when 'profiles' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      into v_rows
      from (
        select id, display_name, username, is_admin, is_system_admin, deleted_at, created_at
        from public.profiles
        where p_include_deleted or deleted_at is null
        order by created_at desc
        limit greatest(p_limit, 1)
      ) t;
    when 'goal_templates' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      into v_rows
      from (
        select id, title, category, cadence, deleted_at, created_at
        from public.goal_templates
        where p_include_deleted or deleted_at is null
        order by title
        limit greatest(p_limit, 1)
      ) t;
    when 'user_goals' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      into v_rows
      from (
        select id, title, mode, status, owner_id, deleted_at, created_at
        from public.user_goals
        where p_include_deleted or deleted_at is null
        order by created_at desc
        limit greatest(p_limit, 1)
      ) t;
    when 'logs' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      into v_rows
      from (
        select id, user_goal_id, author_id, log_date, value, deleted_at, created_at
        from public.logs
        where p_include_deleted or deleted_at is null
        order by created_at desc
        limit greatest(p_limit, 1)
      ) t;
    when 'groups' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      into v_rows
      from (
        select id, name, owner_id, deleted_at, created_at
        from public.groups
        where p_include_deleted or deleted_at is null
        order by created_at desc
        limit greatest(p_limit, 1)
      ) t;
    when 'feedback' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      into v_rows
      from (
        select id, user_id, type, left(message, 120) as message_preview, deleted_at, created_at
        from public.feedback
        where p_include_deleted or deleted_at is null
        order by created_at desc
        limit greatest(p_limit, 1)
      ) t;
    when 'notifications' then
      select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb)
      into v_rows
      from (
        select id, user_id, type, read_at, deleted_at, created_at
        from public.notifications
        where p_include_deleted or deleted_at is null
        order by created_at desc
        limit greatest(p_limit, 1)
      ) t;
    else
      raise exception 'Unsupported table: %', p_table;
  end case;

  return coalesce(v_rows, '[]'::jsonb);
end;
$$;

create or replace function public.admin_delete_goal_template(p_template_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.admin_soft_delete('goal_templates', p_template_id);
end;
$$;

create or replace function public.admin_upsert_goal_template(p_template jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_template public.goal_templates;
  v_id uuid := nullif(p_template->>'id', '')::uuid;
begin
  if not public.is_app_admin() then
    raise exception 'Admin access required';
  end if;

  if v_id is null then
    insert into public.goal_templates (
      title, description, category, metric_type, metric_unit, cadence, default_target, icon
    ) values (
      trim(p_template->>'title'),
      nullif(p_template->>'description', ''),
      p_template->>'category',
      p_template->>'metric_type',
      nullif(p_template->>'metric_unit', ''),
      p_template->>'cadence',
      coalesce(p_template->'default_target', '{}'::jsonb),
      nullif(p_template->>'icon', '')
    )
    returning * into v_template;
  else
    update public.goal_templates
    set
      title = trim(p_template->>'title'),
      description = nullif(p_template->>'description', ''),
      category = p_template->>'category',
      metric_type = p_template->>'metric_type',
      metric_unit = nullif(p_template->>'metric_unit', ''),
      cadence = p_template->>'cadence',
      default_target = coalesce(p_template->'default_target', '{}'::jsonb),
      icon = nullif(p_template->>'icon', ''),
      deleted_at = null,
      deleted_by = null
    where id = v_id
    returning * into v_template;
  end if;

  return to_jsonb(v_template);
end;
$$;

create or replace function public.admin_list_feedback()
returns table (
  id uuid,
  user_id uuid,
  type text,
  message text,
  contact_email text,
  created_at timestamptz,
  author_name text,
  author_username text,
  deleted_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select
    f.id,
    f.user_id,
    f.type,
    f.message,
    f.contact_email,
    f.created_at,
    p.display_name,
    p.username,
    f.deleted_at
  from public.feedback f
  join public.profiles p on p.id = f.user_id
  where public.is_app_admin()
  order by f.created_at desc;
$$;

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
    and l.deleted_at is null
    and ug.deleted_at is null
    and p.deleted_at is null
    and (g.id is null or g.deleted_at is null)
  order by l.created_at desc
  limit greatest(p_limit, 1);
$$;

grant execute on function public.admin_soft_delete(text, uuid) to authenticated;
grant execute on function public.admin_restore(text, uuid) to authenticated;
grant execute on function public.admin_list_records(text, boolean, int) to authenticated;

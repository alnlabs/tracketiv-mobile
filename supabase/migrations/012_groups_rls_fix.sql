-- Safe to run when groups/user_goals already exist (does NOT create tables).
-- Run after 011_groups.sql and 012_groups_rls_fix.sql.

drop policy if exists "Members can view their groups" on public.groups;

create policy "Members can view their groups"
  on public.groups for select
  to authenticated
  using (public.is_group_member(id) or owner_id = auth.uid());

-- Create group server-side (owner from auth.uid(), bypasses client RLS issues)
create or replace function public.create_group(p_name text, p_description text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_group public.groups;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if trim(p_name) = '' then
    raise exception 'Group name is required';
  end if;

  insert into public.groups (name, description, owner_id)
  values (trim(p_name), nullif(trim(p_description), ''), auth.uid())
  returning * into v_group;

  insert into public.group_memberships (group_id, user_id, role)
  values (v_group.id, auth.uid(), 'owner')
  on conflict (group_id, user_id) do nothing;

  return to_jsonb(v_group);
end;
$$;

grant execute on function public.create_group(text, text) to authenticated;

-- Ensure trigger does not duplicate owner row if RPC already inserted membership
create or replace function public.handle_new_group()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.group_memberships (group_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict (group_id, user_id) do nothing;
  return new;
end;
$$;

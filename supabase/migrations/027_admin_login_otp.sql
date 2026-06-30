-- OTP verification for admin logins from unknown devices.

create extension if not exists pgcrypto;

create table if not exists public.admin_trusted_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_label text,
  last_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint admin_trusted_devices_user_device_key unique (user_id, device_id)
);

create index if not exists admin_trusted_devices_user_id_idx
  on public.admin_trusted_devices (user_id);

alter table public.admin_trusted_devices enable row level security;

drop policy if exists "Admins read own trusted devices" on public.admin_trusted_devices;
create policy "Admins read own trusted devices"
  on public.admin_trusted_devices for select
  to authenticated
  using (user_id = auth.uid() and public.is_app_admin());

create table if not exists public.admin_login_otps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts int not null default 0,
  created_at timestamptz not null default now(),
  constraint admin_login_otps_user_device_key unique (user_id, device_id)
);

alter table public.admin_login_otps enable row level security;

create or replace function public.admin_hash_login_otp(p_code text, p_user_id uuid)
returns text
language sql
immutable
as $$
  select encode(digest(p_code || ':' || p_user_id::text, 'sha256'), 'hex');
$$;

create or replace function public.admin_is_device_trusted(p_device_id text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.admin_trusted_devices d
    where d.user_id = auth.uid()
      and d.device_id = trim(p_device_id)
      and public.is_app_admin()
  );
$$;

create or replace function public.admin_verify_login_otp(p_device_id text, p_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_hash text;
  v_row public.admin_login_otps%rowtype;
begin
  if v_user_id is null or not public.is_app_admin() then
    raise exception 'Forbidden';
  end if;

  if p_device_id is null or length(trim(p_device_id)) = 0 then
    raise exception 'Invalid device';
  end if;

  if p_code is null or length(trim(p_code)) != 6 then
    raise exception 'Invalid code';
  end if;

  select * into v_row
  from public.admin_login_otps
  where user_id = v_user_id and device_id = trim(p_device_id)
  for update;

  if not found then
    raise exception 'No pending verification. Request a new code.';
  end if;

  if v_row.expires_at < now() then
    delete from public.admin_login_otps where id = v_row.id;
    raise exception 'Code expired. Request a new one.';
  end if;

  if v_row.attempts >= 5 then
    raise exception 'Too many attempts. Request a new code.';
  end if;

  v_hash := public.admin_hash_login_otp(trim(p_code), v_user_id);

  if v_hash != v_row.code_hash then
    update public.admin_login_otps
    set attempts = attempts + 1
    where id = v_row.id;
    raise exception 'Invalid code';
  end if;

  insert into public.admin_trusted_devices (user_id, device_id, last_verified_at)
  values (v_user_id, trim(p_device_id), now())
  on conflict on constraint admin_trusted_devices_user_device_key
  do update set last_verified_at = excluded.last_verified_at;

  delete from public.admin_login_otps where id = v_row.id;

  return true;
end;
$$;

grant execute on function public.admin_is_device_trusted(text) to authenticated;
grant execute on function public.admin_verify_login_otp(text, text) to authenticated;

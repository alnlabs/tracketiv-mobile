-- Send admin login OTP via Web3Forms (no Edge Function required).
-- After applying, configure once in the Supabase SQL editor:
--   alter database postgres set app.web3forms_access_key = 'your-web3forms-access-key';

create extension if not exists pg_net with schema extensions;

create or replace function public.admin_mask_email(p_email text)
returns text
language sql
immutable
as $$
  select case
    when p_email is null or position('@' in p_email) = 0 then 'your email'
    else
      left(split_part(p_email, '@', 1), 1)
      || repeat('*', greatest(length(split_part(p_email, '@', 1)) - 1, 0))
      || '@'
      || split_part(p_email, '@', 2)
  end;
$$;

create or replace function public.admin_send_login_otp(p_device_id text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text;
  v_code text;
  v_hash text;
  v_key text;
  v_body text;
  v_row public.admin_login_otps%rowtype;
  v_expires_at timestamptz := now() + interval '10 minutes';
begin
  if v_user_id is null or not public.is_app_admin() then
    raise exception 'Forbidden';
  end if;

  if p_device_id is null or length(trim(p_device_id)) = 0 then
    raise exception 'Invalid device';
  end if;

  if exists (
    select 1
    from public.admin_trusted_devices d
    where d.user_id = v_user_id
      and d.device_id = trim(p_device_id)
  ) then
    return jsonb_build_object('ok', true, 'alreadyTrusted', true);
  end if;

  select * into v_row
  from public.admin_login_otps
  where user_id = v_user_id and device_id = trim(p_device_id);

  if found and v_row.created_at > now() - interval '60 seconds' then
    raise exception 'Please wait before requesting another code.';
  end if;

  select u.email into v_email
  from auth.users u
  where u.id = v_user_id;

  if v_email is null or length(trim(v_email)) = 0 then
    raise exception 'No email on account';
  end if;

  v_key := nullif(current_setting('app.web3forms_access_key', true), '');
  if v_key is null then
    raise exception 'Email service not configured';
  end if;

  v_code := lpad((floor(random() * 1000000))::bigint::text, 6, '0');
  v_hash := public.admin_hash_login_otp(v_code, v_user_id);

  insert into public.admin_login_otps (user_id, device_id, code_hash, expires_at, attempts)
  values (v_user_id, trim(p_device_id), v_hash, v_expires_at, 0)
  on conflict on constraint admin_login_otps_user_device_key
  do update set
    code_hash = excluded.code_hash,
    expires_at = excluded.expires_at,
    attempts = 0,
    created_at = now();

  v_body := format(
    E'A sign-in to the Tracketiv admin console was requested from an unrecognized device.\n\nYour verification code is: %s\n\nThis code expires in 10 minutes.\nIf you did not attempt to sign in, change your password immediately.',
    v_code
  );

  perform net.http_post(
    url := 'https://api.web3forms.com/submit',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := jsonb_build_object(
      'access_key', v_key,
      'subject', '[Tracketiv Admin] Sign-in verification code',
      'name', 'Tracketiv Admin',
      'email', v_email,
      'message', v_body
    )
  );

  return jsonb_build_object(
    'ok', true,
    'alreadyTrusted', false,
    'emailHint', public.admin_mask_email(v_email),
    'expiresInMinutes', 10
  );
end;
$$;

grant execute on function public.admin_send_login_otp(text) to authenticated;

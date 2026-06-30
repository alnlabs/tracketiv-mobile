-- Remote push notifications via FCM (device tokens + server trigger)

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios', 'web', 'unknown')),
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  unique (user_id, token)
);

create index device_tokens_user_id_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

create policy "Users can view own device tokens"
  on public.device_tokens for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can insert own device tokens"
  on public.device_tokens for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "Users can update own device tokens"
  on public.device_tokens for update
  to authenticated
  using (user_id = auth.uid());

create policy "Users can delete own device tokens"
  on public.device_tokens for delete
  to authenticated
  using (user_id = auth.uid());

create or replace function public.upsert_device_token(
  p_token text,
  p_platform text default 'unknown'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if char_length(trim(coalesce(p_token, ''))) < 10 then
    raise exception 'Invalid device token';
  end if;

  insert into public.device_tokens (user_id, token, platform, updated_at)
  values (
    auth.uid(),
    trim(p_token),
    coalesce(nullif(p_platform, ''), 'unknown'),
    now()
  )
  on conflict (user_id, token) do update
    set platform = excluded.platform,
        updated_at = now();
end;
$$;

create or replace function public.remove_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  delete from public.device_tokens
  where user_id = auth.uid() and token = trim(p_token);
end;
$$;

grant execute on function public.upsert_device_token(text, text) to authenticated;
grant execute on function public.remove_device_token(text) to authenticated;

-- Optional: call edge function when a notification row is inserted.
-- Configure after deploy (SQL editor, once per project):
--   alter database postgres set app.push_function_url = 'https://YOUR_REF.supabase.co/functions/v1/send-push-notification';
--   alter database postgres set app.push_webhook_secret = 'your-random-secret';
-- Then: supabase secrets set PUSH_WEBHOOK_SECRET=your-random-secret

create extension if not exists pg_net with schema extensions;

create or replace function public.dispatch_push_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
  v_secret text;
begin
  v_url := nullif(current_setting('app.push_function_url', true), '');
  if v_url is null then
    return NEW;
  end if;

  v_secret := nullif(current_setting('app.push_webhook_secret', true), '');

  perform net.http_post(
    url := v_url,
    headers := jsonb_strip_nulls(jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    )),
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'notifications',
      'record', jsonb_build_object(
        'id', NEW.id,
        'user_id', NEW.user_id,
        'type', NEW.type,
        'title', NEW.title,
        'body', NEW.body,
        'data', NEW.data
      )
    )
  );

  return NEW;
end;
$$;

drop trigger if exists notifications_dispatch_push on public.notifications;
create trigger notifications_dispatch_push
  after insert on public.notifications
  for each row execute function public.dispatch_push_notification();

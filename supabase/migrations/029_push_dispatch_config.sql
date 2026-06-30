-- Push dispatch config table (Supabase hosted blocks ALTER DATABASE SET).

create table if not exists public.push_dispatch_config (
  id int primary key default 1 check (id = 1),
  function_url text not null,
  webhook_secret text not null,
  updated_at timestamptz not null default now()
);

alter table public.push_dispatch_config enable row level security;

create or replace function public.dispatch_push_notification()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  v_url text;
  v_secret text;
begin
  select c.function_url, c.webhook_secret
  into v_url, v_secret
  from public.push_dispatch_config c
  where c.id = 1;

  if v_url is null or length(trim(v_url)) = 0 then
    return NEW;
  end if;

  v_secret := nullif(trim(v_secret), '');

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

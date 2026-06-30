-- Run AFTER migration 029 and deploying send-push-notification.
-- webhook_secret must match PUSH_WEBHOOK_SECRET in Edge Function secrets.

insert into public.push_dispatch_config (id, function_url, webhook_secret)
values (
  1,
  'https://qetpxuzzvgnrgkszmoaj.supabase.co/functions/v1/send-push-notification',
  'REPLACE_WITH_PUSH_WEBHOOK_SECRET'
)
on conflict (id) do update set
  function_url = excluded.function_url,
  webhook_secret = excluded.webhook_secret,
  updated_at = now();

-- Verify
select id, function_url, left(webhook_secret, 4) || '…' as secret_preview, updated_at
from public.push_dispatch_config;

select tgname from pg_trigger where tgname = 'notifications_dispatch_push';

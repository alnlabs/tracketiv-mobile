-- Local test data for integration tests and manual QA.
-- Applied on `supabase db reset`. Do NOT run against production.

create extension if not exists pgcrypto;

-- Fixed UUIDs so Flutter + pgTAP tests can reference stable ids.
-- Password for all test users: TestPassword123!

-- ---------------------------------------------------------------------------
-- Test users (auth.users + auth.identities; profiles created via trigger)
-- ---------------------------------------------------------------------------

do $$
declare
  v_pw text := crypt('TestPassword123!', gen_salt('bf'));
begin
  -- Owner: member of test goal, can create logs
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, recovery_sent_at, last_sign_in_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-1111-1111-111111111111',
    'authenticated', 'authenticated',
    'test.owner@tracketiv.local', v_pw,
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{"username":"testowner","display_name":"Test Owner"}',
    now(), now(), '', '', '', ''
  ) on conflict (id) do nothing;

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    '11111111-1111-1111-1111-111111111111',
    '11111111-1111-1111-1111-111111111111',
    jsonb_build_object(
      'sub', '11111111-1111-1111-1111-111111111111',
      'email', 'test.owner@tracketiv.local'
    ),
    'email', '11111111-1111-1111-1111-111111111111',
    now(), now(), now()
  ) on conflict do nothing;

  -- Member: on the same goal, can log but not as another user
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, recovery_sent_at, last_sign_in_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-2222-2222-222222222222',
    'authenticated', 'authenticated',
    'test.member@tracketiv.local', v_pw,
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{"username":"testmember","display_name":"Test Member"}',
    now(), now(), '', '', '', ''
  ) on conflict (id) do nothing;

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    '22222222-2222-2222-2222-222222222222',
    '22222222-2222-2222-2222-222222222222',
    jsonb_build_object(
      'sub', '22222222-2222-2222-2222-222222222222',
      'email', 'test.member@tracketiv.local'
    ),
    'email', '22222222-2222-2222-2222-222222222222',
    now(), now(), now()
  ) on conflict do nothing;

  -- Outsider: authenticated but not on the test goal (RLS negative cases)
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, recovery_sent_at, last_sign_in_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    '33333333-3333-3333-3333-333333333333',
    'authenticated', 'authenticated',
    'test.outsider@tracketiv.local', v_pw,
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{"username":"testoutsider","display_name":"Test Outsider"}',
    now(), now(), '', '', '', ''
  ) on conflict (id) do nothing;

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    '33333333-3333-3333-3333-333333333333',
    '33333333-3333-3333-3333-333333333333',
    jsonb_build_object(
      'sub', '33333333-3333-3333-3333-333333333333',
      'email', 'test.outsider@tracketiv.local'
    ),
    'email', '33333333-3333-3333-3333-333333333333',
    now(), now(), now()
  ) on conflict do nothing;

  -- Admin: management console (is_admin flag set below)
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, recovery_sent_at, last_sign_in_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    '44444444-4444-4444-4444-444444444444',
    'authenticated', 'authenticated',
    'test.admin@tracketiv.local', v_pw,
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{"username":"testadmin","display_name":"Test Admin"}',
    now(), now(), '', '', '', ''
  ) on conflict (id) do nothing;

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    '44444444-4444-4444-4444-444444444444',
    '44444444-4444-4444-4444-444444444444',
    jsonb_build_object(
      'sub', '44444444-4444-4444-4444-444444444444',
      'email', 'test.admin@tracketiv.local'
    ),
    'email', '44444444-4444-4444-4444-444444444444',
    now(), now(), now()
  ) on conflict do nothing;
end $$;

update public.profiles
set is_admin = true
where id = '44444444-4444-4444-4444-444444444444';

-- ---------------------------------------------------------------------------
-- E2E goal template (fixed id for join-goal route tests)
-- ---------------------------------------------------------------------------

insert into public.goal_templates (
  id, title, description, category, metric_type, metric_unit, cadence, default_target, icon
) values (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'E2E Join Template',
  'Template for end-to-end join-goal screen tests.',
  'fitness',
  'steps',
  'steps',
  'daily',
  '{"target_value": 5000}'::jsonb,
  'directions_walk'
) on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Test goal + memberships + seed log
-- ---------------------------------------------------------------------------

insert into public.user_goals (
  id, owner_id, title, mode, cadence, metric_type, metric_unit,
  target_value, status
) values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  'Test Running Goal',
  'solo',
  'daily',
  'distance',
  'km',
  5,
  'active'
) on conflict (id) do nothing;

-- Owner membership is auto-created by on_user_goal_created trigger.
insert into public.goal_memberships (user_goal_id, user_id, role)
values (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '22222222-2222-2222-2222-222222222222',
  'member'
) on conflict (user_goal_id, user_id) do nothing;

insert into public.logs (
  id, user_goal_id, author_id, log_date, value, note
) values (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  '11111111-1111-1111-1111-111111111111',
  current_date - 1,
  3.5,
  'Seed log from yesterday'
) on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Test group + group goal (for group / members E2E screens)
-- ---------------------------------------------------------------------------

insert into public.groups (id, name, description, owner_id)
values (
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'E2E Test Group',
  'Seed group for E2E navigation tests.',
  '11111111-1111-1111-1111-111111111111'
) on conflict (id) do nothing;

insert into public.group_memberships (group_id, user_id, role)
values
  (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '11111111-1111-1111-1111-111111111111',
    'owner'
  ),
  (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '22222222-2222-2222-2222-222222222222',
    'member'
  )
on conflict (group_id, user_id) do nothing;

insert into public.user_goals (
  id, owner_id, title, mode, cadence, metric_type, metric_unit,
  target_value, status, group_id
) values (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  '11111111-1111-1111-1111-111111111111',
  'E2E Group Steps Goal',
  'group',
  'daily',
  'steps',
  'steps',
  8000,
  'active',
  'cccccccc-cccc-cccc-cccc-cccccccccccc'
) on conflict (id) do nothing;

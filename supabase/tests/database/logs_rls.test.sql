-- pgTAP: logs RLS + author_id column (not user_id)
begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

-- logs table must use author_id (regression for release bug)
select has_column('public', 'logs', 'author_id', 'logs has author_id column');
select hasnt_column('public', 'logs', 'user_id', 'logs must not have user_id column');

-- Owner can insert a log for today
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$
    insert into public.logs (user_goal_id, author_id, log_date, value, note)
    values (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '11111111-1111-1111-1111-111111111111',
      current_date,
      4.2,
      'pgTAP owner insert'
    )
  $$,
  'goal owner can insert log with author_id'
);

-- Member can insert their own log
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

select lives_ok(
  $$
    insert into public.logs (user_goal_id, author_id, log_date, value)
    values (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '22222222-2222-2222-2222-222222222222',
      current_date,
      2.0
    )
  $$,
  'goal member can insert own log'
);

-- Outsider cannot insert (RLS)
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

select throws_ok(
  $$
    insert into public.logs (user_goal_id, author_id, log_date, value)
    values (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      '33333333-3333-3333-3333-333333333333',
      current_date,
      1.0
    )
  $$,
  '42501',
  null,
  'outsider cannot insert log on foreign goal'
);

-- Outsider cannot read logs on foreign goal
select is_empty(
  $$
    select 1 from public.logs
    where user_goal_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  $$,
  'outsider cannot read logs on foreign goal'
);

select * from finish();
rollback;

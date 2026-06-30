-- pgTAP: log_comments RLS
begin;

create extension if not exists pgtap with schema extensions;

select plan(3);

set local role authenticated;
set local request.jwt.claim.role = 'authenticated';

-- Member can comment on a log they can see
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

select lives_ok(
  $$
    insert into public.log_comments (log_id, author_id, body)
    values (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      '22222222-2222-2222-2222-222222222222',
      'pgTAP test comment'
    )
  $$,
  'member can add comment on goal log'
);

-- Outsider cannot comment
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

select throws_ok(
  $$
    insert into public.log_comments (log_id, author_id, body)
    values (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      '33333333-3333-3333-3333-333333333333',
      'should fail'
    )
  $$,
  '42501',
  null,
  'outsider cannot comment on foreign goal log'
);

-- Member can read comments
set local request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

select ok(
  (select count(*) > 0 from public.log_comments
   where log_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  'member can read comments on goal log'
);

select * from finish();
rollback;

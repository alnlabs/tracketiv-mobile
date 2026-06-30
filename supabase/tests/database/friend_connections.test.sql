-- pgTAP: mutual friends + feed visibility
begin;

create extension if not exists pgtap with schema extensions;

select plan(6);

select has_table('public', 'friend_requests', 'friend_requests table exists');
select has_table('public', 'friendships', 'friendships table exists');

-- Owner sends request to outsider
set local role authenticated;
set local request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set local request.jwt.claim.role = 'authenticated';

select lives_ok(
  $$
    select public.send_friend_request('33333333-3333-3333-3333-333333333333'::uuid)
  $$,
  'owner can send friend request'
);

-- Outsider accepts
set local request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

select lives_ok(
  $$
    select public.respond_friend_request(
      (
        select id from public.friend_requests
        where requester_id = '11111111-1111-1111-1111-111111111111'
          and addressee_id = '33333333-3333-3333-3333-333333333333'
          and status = 'pending'
        limit 1
      ),
      true
    )
  $$,
  'outsider can accept friend request'
);

select ok(
  public.are_friends(
    '11111111-1111-1111-1111-111111111111',
    '33333333-3333-3333-3333-333333333333'
  ),
  'friendship exists after accept'
);

select ok(
  (
    select count(*) > 0
    from public.get_my_feed(100) f
    where f.author_id = '11111111-1111-1111-1111-111111111111'
  ),
  'outsider feed includes owner logs after friendship'
);

select * from finish();
rollback;

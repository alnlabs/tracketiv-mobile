-- Daily quote: more topics, multi-category pool filter, clearer config.

-- ---------------------------------------------------------------------------
-- Expand quote pool categories
-- ---------------------------------------------------------------------------

alter table public.feed_quote_pool
  drop constraint if exists feed_quote_pool_category_check;

alter table public.feed_quote_pool
  add constraint feed_quote_pool_category_check
  check (category in ('goal', 'life', 'community', 'motivation', 'mindfulness', 'success'));

insert into public.feed_quote_pool (text, author, category) values
  ('Motivation gets you started. Habit keeps you going.', 'Jim Ryun', 'motivation'),
  ('You don''t have to be great to start, but you have to start to be great.', 'Zig Ziglar', 'motivation'),
  ('Believe you can and you''re halfway there.', 'Theodore Roosevelt', 'motivation'),
  ('Breathe. You are exactly where you need to be.', 'Tracketiv', 'mindfulness'),
  ('Almost everything will work again if you unplug it for a few minutes — including you.', 'Anne Lamott', 'mindfulness'),
  ('Wherever you are, be all there.', 'Jim Elliot', 'mindfulness'),
  ('Success is liking yourself, liking what you do, and liking how you do it.', 'Maya Angelou', 'success'),
  ('Don''t watch the clock; do what it does. Keep going.', 'Sam Levenson', 'success'),
  ('The only place where success comes before work is in the dictionary.', 'Vidal Sassoon', 'success');

-- ---------------------------------------------------------------------------
-- Pool resolver: categories[] multi-select; empty = all topics (random mix)
-- ---------------------------------------------------------------------------

create or replace function public.resolve_feed_widget_quote_content(
  p_widget_id uuid,
  p_slot_date date,
  p_config jsonb
)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_source text;
  v_text text;
  v_author text;
  v_category text;
  v_pool_count int;
  v_offset int;
  v_row record;
  v_categories jsonb;
begin
  v_source := coalesce(p_config->>'source', 'pool');

  if v_source = 'custom' then
    v_text := nullif(trim(p_config->>'text'), '');
    v_author := nullif(trim(p_config->>'author'), '');
    v_category := coalesce(nullif(p_config->>'category', ''), 'goal');
    if v_text is not null then
      return jsonb_build_object(
        'text', v_text,
        'author', coalesce(v_author, 'You'),
        'category', v_category
      );
    end if;
  end if;

  v_categories := p_config->'categories';
  if v_categories is not null and jsonb_typeof(v_categories) = 'array'
     and jsonb_array_length(v_categories) > 0 then
    select count(*)::int into v_pool_count
    from public.feed_quote_pool q
    where q.category in (
      select jsonb_array_elements_text(v_categories)
    );

    if v_pool_count > 0 then
      v_offset := abs(hashtext(p_widget_id::text || p_slot_date::text)) % v_pool_count;

      select text, author, category
      into v_row
      from public.feed_quote_pool q
      where q.category in (
        select jsonb_array_elements_text(v_categories)
      )
      order by q.id
      offset v_offset
      limit 1;

      return jsonb_build_object(
        'text', v_row.text,
        'author', v_row.author,
        'category', v_row.category
      );
    end if;
  elsif nullif(p_config->>'category', '') is not null then
    select count(*)::int into v_pool_count
    from public.feed_quote_pool q
    where q.category = p_config->>'category';

    if v_pool_count > 0 then
      v_offset := abs(hashtext(p_widget_id::text || p_slot_date::text)) % v_pool_count;

      select text, author, category
      into v_row
      from public.feed_quote_pool q
      where q.category = p_config->>'category'
      order by q.id
      offset v_offset
      limit 1;

      return jsonb_build_object(
        'text', v_row.text,
        'author', v_row.author,
        'category', v_row.category
      );
    end if;
  end if;

  select count(*)::int into v_pool_count from public.feed_quote_pool;
  if v_pool_count = 0 then
    return jsonb_build_object(
      'text', 'Small steps every day add up to big change.',
      'author', 'Tracketiv',
      'category', 'goal'
    );
  end if;

  v_offset := abs(hashtext(p_widget_id::text || p_slot_date::text)) % v_pool_count;

  select text, author, category
  into v_row
  from public.feed_quote_pool
  order by id
  offset v_offset
  limit 1;

  return jsonb_build_object(
    'text', v_row.text,
    'author', v_row.author,
    'category', v_row.category
  );
end;
$$;

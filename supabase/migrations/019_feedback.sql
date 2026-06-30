-- User feedback: suggestions, improvements, and issues

create table public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('suggestion', 'improvement', 'issue')),
  message text not null check (char_length(trim(message)) >= 10),
  contact_email text,
  created_at timestamptz default now() not null
);

create index feedback_created_idx on public.feedback (created_at desc);

alter table public.feedback enable row level security;

create policy "Users can view own feedback"
  on public.feedback for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can submit feedback"
  on public.feedback for insert
  to authenticated
  with check (user_id = auth.uid());

create or replace function public.submit_feedback(
  p_type text,
  p_message text,
  p_contact_email text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_email text;
begin
  if p_type not in ('suggestion', 'improvement', 'issue') then
    raise exception 'Invalid feedback type';
  end if;

  if char_length(trim(p_message)) < 10 then
    raise exception 'Message must be at least 10 characters';
  end if;

  select coalesce(nullif(trim(p_contact_email), ''), u.email)
  into v_email
  from auth.users u
  where u.id = auth.uid();

  insert into public.feedback (user_id, type, message, contact_email)
  values (auth.uid(), p_type, trim(p_message), v_email)
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.submit_feedback(text, text, text) to authenticated;

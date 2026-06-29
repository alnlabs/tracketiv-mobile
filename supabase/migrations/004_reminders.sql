-- Phase 4: Reminders

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_goal_id uuid not null references public.user_goals(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  time_of_day time not null default '20:00',
  days_of_week int[] not null default '{1,2,3,4,5,6,7}',
  enabled boolean not null default true,
  last_sent_at timestamptz,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null,
  unique (user_goal_id, user_id)
);

alter table public.reminders enable row level security;

create policy "Users can view own reminders"
  on public.reminders for select
  to authenticated
  using (user_id = auth.uid());

create policy "Users can create own reminders"
  on public.reminders for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and public.is_goal_member(user_goal_id)
  );

create policy "Users can update own reminders"
  on public.reminders for update
  to authenticated
  using (user_id = auth.uid());

create policy "Users can delete own reminders"
  on public.reminders for delete
  to authenticated
  using (user_id = auth.uid());

create trigger reminders_updated_at
  before update on public.reminders
  for each row execute function public.handle_updated_at();

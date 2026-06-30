-- Current body weight on profile (stored in kg)

alter table public.profiles
  add column if not exists weight_kg numeric;

comment on column public.profiles.weight_kg is 'Current body weight stored in kilograms';

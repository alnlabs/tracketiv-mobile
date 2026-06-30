-- Extended profile fields

alter table public.profiles
  add column if not exists bio text,
  add column if not exists date_of_birth date,
  add column if not exists gender text check (
    gender is null or gender in ('male', 'female', 'other', 'prefer_not_to_say')
  ),
  add column if not exists height_cm numeric,
  add column if not exists country text,
  add column if not exists city text,
  add column if not exists phone text,
  add column if not exists weight_unit text default 'kg' check (weight_unit in ('kg', 'lbs'));

comment on column public.profiles.bio is 'Short bio visible to group members';
comment on column public.profiles.height_cm is 'Height in centimeters for fitness goal context';
comment on column public.profiles.weight_unit is 'Preferred unit for weight goals: kg or lbs';

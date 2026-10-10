alter table public.profiles
  add column if not exists phone text,
  add column if not exists professional_title text,
  add column if not exists business_name text,
  add column if not exists location text,
  add column if not exists website text;

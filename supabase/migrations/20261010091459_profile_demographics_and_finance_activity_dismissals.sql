-- Keep the existing profile editor's fields in sync with production, then add
-- privacy-minimizing demographic fields for aggregate usage comparisons.
alter table public.profiles
  add column if not exists phone text,
  add column if not exists professional_title text,
  add column if not exists business_name text,
  add column if not exists location text,
  add column if not exists website text,
  add column if not exists country text,
  add column if not exists age_range text,
  add column if not exists gender text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_age_range_allowed'
  ) then
    alter table public.profiles
      add constraint profiles_age_range_allowed
      check (age_range is null or age_range in
        ('18_24', '25_34', '35_44', '45_54', '55_plus'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_gender_allowed'
  ) then
    alter table public.profiles
      add constraint profiles_gender_allowed
      check (gender is null or gender in ('woman', 'man', 'non_binary'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_country_length'
  ) then
    alter table public.profiles
      add constraint profiles_country_length
      check (country is null or length(trim(country)) between 1 and 80);
  end if;
end;
$$;

comment on column public.profiles.country is
  'Self-reported country for aggregate product-usage analysis.';
comment on column public.profiles.age_range is
  'Self-reported age band; no exact date of birth is collected.';
comment on column public.profiles.gender is
  'Self-reported gender for aggregate product-usage analysis.';

-- These records persist each user's dismissed transaction activity notice
-- across browsers and logins without deleting the income/expense itself.
create table if not exists public.finance_activity_dismissals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_type text not null check (activity_type in ('income', 'expense')),
  transaction_id uuid not null,
  is_dismissed boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, activity_type, transaction_id)
);

alter table public.finance_activity_dismissals enable row level security;
revoke all on table public.finance_activity_dismissals from public, anon;
grant select, insert, update on table public.finance_activity_dismissals
  to authenticated;

drop policy if exists "Users can read own finance activity dismissals"
  on public.finance_activity_dismissals;
create policy "Users can read own finance activity dismissals"
  on public.finance_activity_dismissals for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create own finance activity dismissals"
  on public.finance_activity_dismissals;
create policy "Users can create own finance activity dismissals"
  on public.finance_activity_dismissals for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own finance activity dismissals"
  on public.finance_activity_dismissals;
create policy "Users can update own finance activity dismissals"
  on public.finance_activity_dismissals for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Preserve the verified account-delete cascade for this newly added table.
grant usage on schema public to supabase_auth_admin;
grant delete on table public.finance_activity_dismissals
  to supabase_auth_admin;

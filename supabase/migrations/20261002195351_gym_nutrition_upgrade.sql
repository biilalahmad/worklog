-- Gym nutrition upgrade. Apply to the connected Supabase project.
alter table public.foods
  add column if not exists barcode text,
  add column if not exists source text not null default 'manual';

create index if not exists idx_foods_barcode on public.foods (barcode);

create table if not exists public.water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  date date not null default current_date,
  milliliters integer not null default 250
    check (milliliters > 0 and milliliters <= 10000),
  created_at timestamptz not null default now()
);

alter table public.water_logs enable row level security;
drop policy if exists "own water logs" on public.water_logs;
create policy "own water logs" on public.water_logs
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create index if not exists idx_water_logs_user_date
  on public.water_logs (user_id, date desc);

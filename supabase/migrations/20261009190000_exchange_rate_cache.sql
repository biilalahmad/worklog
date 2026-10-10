-- Shared daily exchange-rate cache. Only the Edge Function's service role
-- may access this table; signed-in clients read rates through the function.
create table if not exists public.exchange_rate_cache (
  id smallint primary key default 1 check (id = 1),
  rates jsonb,
  base_code text not null default 'USD',
  provider_updated_at timestamptz,
  next_update_at timestamptz,
  last_attempt_at timestamptz not null default '1970-01-01 00:00:00+00',
  updated_at timestamptz not null default now()
);

insert into public.exchange_rate_cache (id)
values (1)
on conflict (id) do nothing;

alter table public.exchange_rate_cache enable row level security;
revoke all on table public.exchange_rate_cache from anon, authenticated;
grant all on table public.exchange_rate_cache to service_role;

-- Keep password-reset account lookup server-only. The app receives only the
-- boolean result through the account-security Edge Function; no auth.users
-- rows or service-role credentials are exposed to clients.
create or replace function public.auth_account_exists_by_email(p_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users as auth_user
    where auth_user.email is not null
      and lower(auth_user.email) = lower(trim(p_email))
  );
$$;

revoke all on function public.auth_account_exists_by_email(text)
  from public, anon, authenticated;
grant execute on function public.auth_account_exists_by_email(text)
  to service_role;

-- The explicit account-existence response is rate-limited by client network
-- address as well as by the existing per-email daily reset-code limit.
create table if not exists private.auth_reset_lookup_events (
  id bigint generated always as identity primary key,
  ip_digest text not null check (ip_digest ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default clock_timestamp()
);

alter table private.auth_reset_lookup_events enable row level security;
revoke all on table private.auth_reset_lookup_events
  from public, anon, authenticated;
grant select, insert, delete on table private.auth_reset_lookup_events
  to service_role;

create index if not exists auth_reset_lookup_events_ip_time_idx
  on private.auth_reset_lookup_events (ip_digest, created_at desc);
create index if not exists auth_reset_lookup_events_created_at_idx
  on private.auth_reset_lookup_events (created_at);

create or replace function public.reserve_auth_reset_lookup(p_ip_digest text)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare
  v_now timestamptz := clock_timestamp();
  v_count integer;
begin
  if p_ip_digest is null or p_ip_digest !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid reset lookup key';
  end if;

  -- Serialize requests from one client so concurrent calls cannot exceed the
  -- per-address hourly lookup budget. Store only an HMAC, never the raw IP.
  perform pg_advisory_xact_lock(hashtextextended(p_ip_digest, 192837));

  delete from private.auth_reset_lookup_events
  where created_at <= v_now - interval '1 hour';

  select count(*)::integer into v_count
  from private.auth_reset_lookup_events
  where ip_digest = p_ip_digest
    and created_at > v_now - interval '1 hour';

  if v_count >= 10 then return false; end if;

  insert into private.auth_reset_lookup_events(ip_digest, created_at)
  values (p_ip_digest, v_now);
  return true;
end;
$$;

revoke all on function public.reserve_auth_reset_lookup(text)
  from public, anon, authenticated;
grant execute on function public.reserve_auth_reset_lookup(text)
  to service_role;

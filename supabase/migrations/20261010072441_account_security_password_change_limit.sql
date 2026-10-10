-- Keep onboarding exclusive to accounts created after this rollout. New
-- profile rows retain the default false value and complete setup themselves.
alter table public.profiles
  add column if not exists onboarding_done boolean not null default false;

update public.profiles
set onboarding_done = true
where onboarding_done = false;

-- Password changes are limited by a rolling 24-hour window. Reservations
-- count against the limit while Auth is being updated, and are removed if
-- the Auth mutation fails.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create table if not exists private.auth_password_change_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp(),
  status text not null default 'reserved'
    check (status in ('reserved', 'completed'))
);

alter table private.auth_password_change_events enable row level security;
revoke all on table private.auth_password_change_events
  from public, anon, authenticated;
grant select, insert, update, delete on table private.auth_password_change_events
  to service_role;

create index if not exists auth_password_change_events_user_time_idx
  on private.auth_password_change_events (user_id, created_at desc);

-- This invoker function is callable only by the Edge Function's service role.
-- The advisory lock and ticket consumption happen in one transaction, so
-- concurrent requests cannot exceed the per-user limit or burn a valid ticket
-- when the limit has already been reached.
create or replace function public.consume_and_reserve_password_change(
  p_user_id uuid,
  p_email text,
  p_ticket_hash text
) returns table (
  consumed_user_id uuid,
  reservation_id uuid,
  limit_reached boolean
)
language plpgsql
security invoker
set search_path = pg_catalog, private
as $$
declare
  v_count integer;
  v_user_id uuid;
  v_reservation_id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  delete from private.auth_password_change_events
  where user_id = p_user_id
    and created_at <= clock_timestamp() - interval '24 hours';

  select count(*)::integer into v_count
  from private.auth_password_change_events
  where user_id = p_user_id
    and created_at > clock_timestamp() - interval '24 hours';

  if v_count >= 7 then
    return query select null::uuid, null::uuid, true;
    return;
  end if;

  v_user_id := public.consume_auth_action_ticket(
    p_email, 'change_password', p_ticket_hash, p_user_id
  );
  if v_user_id is null then
    return query select null::uuid, null::uuid, false;
    return;
  end if;

  insert into private.auth_password_change_events (user_id)
  values (p_user_id)
  returning id into v_reservation_id;

  return query select v_user_id, v_reservation_id, false;
end;
$$;

create or replace function public.complete_password_change_reservation(
  p_user_id uuid,
  p_reservation_id uuid
) returns boolean
language plpgsql
security invoker
set search_path = pg_catalog, private
as $$
begin
  update private.auth_password_change_events
  set status = 'completed'
  where id = p_reservation_id
    and user_id = p_user_id
    and status = 'reserved'
    and created_at > clock_timestamp() - interval '24 hours';
  return found;
end;
$$;

create or replace function public.cancel_password_change_reservation(
  p_user_id uuid,
  p_reservation_id uuid
) returns boolean
language plpgsql
security invoker
set search_path = pg_catalog, private
as $$
begin
  delete from private.auth_password_change_events
  where id = p_reservation_id
    and user_id = p_user_id
    and status = 'reserved';
  return found;
end;
$$;

revoke all on function public.consume_and_reserve_password_change(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.complete_password_change_reservation(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.cancel_password_change_reservation(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.consume_and_reserve_password_change(uuid, text, text)
  to service_role;
grant execute on function public.complete_password_change_reservation(uuid, uuid)
  to service_role;
grant execute on function public.cancel_password_change_reservation(uuid, uuid)
  to service_role;

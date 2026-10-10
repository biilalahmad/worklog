-- Server-side, single-use authorization tickets for email-verified
-- password changes/resets and account deletion.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create table if not exists private.auth_action_challenges (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  action text not null check (action in ('reset_password', 'change_password', 'delete_account')),
  requested_at timestamptz not null,
  expires_at timestamptz not null,
  user_id uuid references auth.users(id) on delete cascade,
  ticket_hash text unique,
  consumed_at timestamptz,
  unique (email, action),
  check (expires_at > requested_at)
);

alter table private.auth_action_challenges enable row level security;
revoke all on table private.auth_action_challenges from public, anon, authenticated;
grant select, insert, update, delete on table private.auth_action_challenges to service_role;

create or replace function public.prepare_auth_action_challenge(
  p_email text,
  p_action text,
  p_requested_at timestamptz
) returns void
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
begin
  if p_action not in ('reset_password', 'change_password', 'delete_account') then
    raise exception 'Invalid security action';
  end if;
  if p_email is null or length(trim(p_email)) = 0 then
    raise exception 'Email is required';
  end if;

  -- A resend replaces every outstanding code/ticket for this account,
  -- regardless of which sensitive action originally requested it.
  perform pg_advisory_xact_lock(hashtextextended(lower(trim(p_email)), 0));
  update private.auth_action_challenges
  set expires_at = least(expires_at, clock_timestamp()),
      user_id = null,
      ticket_hash = null,
      consumed_at = coalesce(consumed_at, clock_timestamp())
  where email = lower(trim(p_email));

  insert into private.auth_action_challenges (
    email, action, requested_at, expires_at, user_id, ticket_hash, consumed_at
  ) values (
    lower(trim(p_email)), p_action, p_requested_at,
    p_requested_at + interval '180 seconds', null, null, null
  )
  on conflict (email, action) do update set
    requested_at = excluded.requested_at,
    expires_at = excluded.expires_at,
    user_id = null,
    ticket_hash = null,
    consumed_at = null;
end;
$$;

create or replace function public.issue_auth_action_ticket(
  p_email text,
  p_action text,
  p_user_id uuid,
  p_ticket_hash text
) returns boolean
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
begin
  if p_ticket_hash is null or length(p_ticket_hash) <> 64 then
    return false;
  end if;

  update private.auth_action_challenges
  set user_id = p_user_id,
      ticket_hash = p_ticket_hash
  where email = lower(trim(p_email))
    and action = p_action
    and requested_at <= clock_timestamp()
    and expires_at > clock_timestamp()
    and user_id is null
    and ticket_hash is null
    and consumed_at is null;

  return found;
end;
$$;

create or replace function public.consume_auth_action_ticket(
  p_email text,
  p_action text,
  p_ticket_hash text,
  p_expected_user_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, private
as $$
declare
  v_user_id uuid;
begin
  update private.auth_action_challenges
  set consumed_at = clock_timestamp()
  where email = lower(trim(p_email))
    and action = p_action
    and ticket_hash = p_ticket_hash
    and ticket_hash is not null
    and consumed_at is null
    and expires_at > clock_timestamp()
    and (p_expected_user_id is null or user_id = p_expected_user_id)
  returning user_id into v_user_id;

  return v_user_id;
end;
$$;

revoke all on function public.prepare_auth_action_challenge(text, text, timestamptz) from public, anon, authenticated;
revoke all on function public.issue_auth_action_ticket(text, text, uuid, text) from public, anon, authenticated;
revoke all on function public.consume_auth_action_ticket(text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.prepare_auth_action_challenge(text, text, timestamptz) to service_role;
grant execute on function public.issue_auth_action_ticket(text, text, uuid, text) to service_role;
grant execute on function public.consume_auth_action_ticket(text, text, text, uuid) to service_role;

-- The legacy RPC had no reauthentication requirement. Fail closed; all
-- account deletion must pass through the OTP-verifying Edge Function.
create or replace function public.delete_my_account() returns void
language plpgsql
security invoker
set search_path = pg_catalog
as $$
begin
  raise exception 'Account deletion requires a verified email code';
end;
$$;
revoke all on function public.delete_my_account() from public, anon, authenticated, service_role;

-- Track code-send attempts separately for each sensitive action and account.
-- The rolling 24-hour limit is enforced server-side by account-security.
create table if not exists private.auth_action_code_request_events (
  id uuid primary key default gen_random_uuid(),
  action text not null
    check (action in ('reset_password', 'change_password', 'delete_account')),
  email text not null,
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp(),
  check (
    (action = 'reset_password' and user_id is null)
    or (action <> 'reset_password' and user_id is not null)
  )
);

alter table private.auth_action_code_request_events enable row level security;
revoke all on table private.auth_action_code_request_events
  from public, anon, authenticated;
grant select, insert, delete on table private.auth_action_code_request_events
  to service_role;

create index if not exists auth_action_code_requests_account_time_idx
  on private.auth_action_code_request_events (action, email, created_at desc);

create or replace function public.reserve_auth_action_code_request(
  p_action text,
  p_email text,
  p_user_id uuid default null
) returns boolean
language plpgsql
security invoker
set search_path = pg_catalog, private
as $$
declare
  v_email text := lower(trim(p_email));
  v_count integer;
begin
  if p_action not in ('reset_password', 'change_password', 'delete_account')
    or v_email is null or v_email = ''
    or (p_action = 'reset_password' and p_user_id is not null)
    or (p_action <> 'reset_password' and p_user_id is null) then
    raise exception 'Invalid code request';
  end if;

  -- Serialize concurrent sends for this action/account so parallel requests
  -- cannot exceed the seven-request limit.
  perform pg_advisory_xact_lock(
    hashtextextended(p_action || ':' || v_email, 0)
  );

  delete from private.auth_action_code_request_events
  where action = p_action
    and email = v_email
    and created_at <= clock_timestamp() - interval '24 hours';

  select count(*)::integer into v_count
  from private.auth_action_code_request_events
  where action = p_action
    and email = v_email
    and created_at > clock_timestamp() - interval '24 hours';

  if v_count >= 7 then return false; end if;

  insert into private.auth_action_code_request_events(action, email, user_id)
  values (p_action, v_email, p_user_id);
  return true;
end;
$$;

revoke all on function public.reserve_auth_action_code_request(text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.reserve_auth_action_code_request(text, text, uuid)
  to service_role;

-- Auth deletes auth.users as supabase_auth_admin. Give that internal role
-- only the DELETE rights needed for existing ON DELETE CASCADE descendants;
-- this is necessary for user deletion to remove the user's own app data.
do $$
declare
  target record;
begin
  execute 'grant usage on schema public, private to supabase_auth_admin';
  for target in
    with recursive cascade_tables(table_oid) as (
      select conrelid
      from pg_constraint
      where contype = 'f'
        and confdeltype = 'c'
        and confrelid = 'auth.users'::regclass
      union
      select constraint_row.conrelid
      from pg_constraint constraint_row
      join cascade_tables parent_table
        on constraint_row.confrelid = parent_table.table_oid
      where constraint_row.contype = 'f'
        and constraint_row.confdeltype = 'c'
    )
    select distinct namespace_row.nspname, relation_row.relname
    from cascade_tables
    join pg_class relation_row on relation_row.oid = cascade_tables.table_oid
    join pg_namespace namespace_row on namespace_row.oid = relation_row.relnamespace
    where namespace_row.nspname in ('public', 'private')
      and relation_row.relkind in ('r', 'p')
  loop
    execute format(
      'grant delete on table %I.%I to supabase_auth_admin',
      target.nspname,
      target.relname
    );
  end loop;
end;
$$;

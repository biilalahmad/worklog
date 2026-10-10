-- =====================================================================
-- WorkLog — Supabase schema
-- Run this once in: Supabase Dashboard → SQL Editor → New query → Run
-- Personal, single-user app: no auth tables, no row-level multi-tenant
-- columns. See the bottom of this file for notes on RLS.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- clients
-- ---------------------------------------------------------------------
create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  avatar_url text,
  email text,
  phone text,
  notes text,
  created_at timestamptz not null default now(),
  -- Rollup columns below are written ONLY by the triggers further down.
  -- The app never writes them directly, so they can't drift from the
  -- underlying income/work records.
  total_earned jsonb not null default '{}'::jsonb,
  total_pending jsonb not null default '{}'::jsonb,
  total_videos_completed integer not null default 0,
  last_activity_at timestamptz
);
create index if not exists idx_clients_name on clients (name);

-- ---------------------------------------------------------------------
-- projects
-- ---------------------------------------------------------------------
create table if not exists projects (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients (id) on delete cascade,
  title text not null,
  total_amount bigint not null default 0, -- minor units (paisa/cents)
  currency text not null default 'PKR',
  due_date timestamptz,
  created_at timestamptz not null default now(),
  amount_paid bigint not null default 0,
  amount_remaining bigint not null default 0,
  status text not null default 'unpaid' -- unpaid | partiallyPaid | paid
);
create index if not exists idx_projects_client on projects (client_id);
create index if not exists idx_projects_status on projects (status);
create index if not exists idx_projects_due_date on projects (due_date);

-- ---------------------------------------------------------------------
-- work_entries
-- ---------------------------------------------------------------------
create table if not exists work_entries (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients (id) on delete cascade,
  project_id uuid references projects (id) on delete set null,
  task_name text not null,
  work_type text not null default '',
  video_count integer not null default 0,
  other_task_count integer not null default 0,
  hours_worked numeric not null default 0,
  status text not null default 'pending',
  date timestamptz not null default now(),
  due_date timestamptz,
  completion_date timestamptz,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists idx_work_entries_date on work_entries (date desc);
create index if not exists idx_work_entries_client on work_entries (client_id, date desc);
create index if not exists idx_work_entries_status on work_entries (status);

-- ---------------------------------------------------------------------
-- income (payments received)
-- ---------------------------------------------------------------------
create table if not exists income (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients (id) on delete cascade,
  project_id uuid references projects (id) on delete set null,
  amount bigint not null default 0, -- minor units
  currency text not null default 'PKR',
  date timestamptz not null default now(),
  method text not null default '',
  description text,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists idx_income_date on income (date desc);
create index if not exists idx_income_client on income (client_id, date desc);

-- ---------------------------------------------------------------------
-- expenses
-- ---------------------------------------------------------------------
create table if not exists expenses (
  id uuid primary key default gen_random_uuid(),
  amount bigint not null default 0,
  currency text not null default 'PKR',
  date timestamptz not null default now(),
  category text not null default '',
  description text,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists idx_expenses_date on expenses (date desc);

-- ---------------------------------------------------------------------
-- reminders
-- ---------------------------------------------------------------------
create table if not exists reminders (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  date_time timestamptz not null,
  client_id uuid references clients (id) on delete set null,
  project_id uuid references projects (id) on delete set null,
  priority text not null default 'medium',
  repeat text not null default 'none',
  completed boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_reminders_datetime on reminders (date_time);
create index if not exists idx_reminders_completed on reminders (completed, date_time);

-- ---------------------------------------------------------------------
-- daily_notes (one journal entry per day, keyed by yyyy-MM-dd)
-- ---------------------------------------------------------------------
create table if not exists daily_notes (
  date_key text primary key,
  content text not null default '',
  updated_at timestamptz not null default now()
);

-- =====================================================================
-- Rollup triggers — replace what Cloud Functions used to do.
-- =====================================================================

-- Add `delta` to jsonb map key `currency`, dropping the key at 0.
create or replace function jsonb_currency_add(target jsonb, ccy text, delta numeric)
returns jsonb language plpgsql immutable as $$
declare
  current numeric;
  updated numeric;
begin
  current := coalesce((target ->> ccy)::numeric, 0);
  updated := current + delta;
  if updated = 0 then
    return target - ccy;
  end if;
  return jsonb_set(target, array[ccy], to_jsonb(updated), true);
end;
$$;

-- income -> client's total_earned + project amount_paid/status.
-- (total_pending is intentionally NOT touched here — see
-- fn_project_pending_rollup below. Earlier versions of this schema
-- decremented total_pending by the income delta directly, which was
-- wrong: a tip or any income with no linked project would push
-- total_pending negative even though nothing was ever "pending" for
-- it. Pending must only reflect real outstanding project balances.)
create or replace function fn_income_rollup() returns trigger
language plpgsql as $$
declare
  v_client_id uuid := coalesce(new.client_id, old.client_id);
  v_project_id uuid := coalesce(new.project_id, old.project_id);
  v_currency text := coalesce(new.currency, old.currency, 'PKR');
  v_before numeric := case when tg_op = 'INSERT' then 0 else coalesce(old.amount, 0) end;
  v_after numeric := case when tg_op = 'DELETE' then 0 else coalesce(new.amount, 0) end;
  v_delta numeric := v_after - v_before;
  v_total bigint;
  v_paid bigint;
  v_remaining bigint;
  v_status text;
begin
  if v_delta <> 0 and v_client_id is not null then
    update clients
    set total_earned = jsonb_currency_add(total_earned, v_currency, v_delta),
        last_activity_at = now()
    where id = v_client_id;
  end if;

  if v_project_id is not null and v_delta <> 0 then
    select total_amount, amount_paid into v_total, v_paid from projects where id = v_project_id for update;
    if found then
      v_paid := v_paid + v_delta;
      v_remaining := v_total - v_paid;
      v_status := case
        when v_paid <= 0 then 'unpaid'
        when v_remaining <= 0 then 'paid'
        else 'partiallyPaid'
      end;
      update projects
      set amount_paid = v_paid, amount_remaining = v_remaining, status = v_status
      where id = v_project_id;
      -- updating `projects` here fires trg_project_pending_rollup below,
      -- which recomputes the client's total_pending from every project's
      -- actual remaining balance — so it can never drift or go negative.
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_income_rollup on income;
create trigger trg_income_rollup
after insert or update or delete on income
for each row execute function fn_income_rollup();

-- Recomputes one client's total_pending from scratch: the sum of every
-- one of their projects' outstanding balance (never negative — an
-- overpaid project contributes 0, not a negative number). This is a
-- full recompute rather than an incremental delta, so it can never
-- drift out of sync with the projects table.
create or replace function fn_recompute_client_pending(p_client_id uuid) returns void
language plpgsql as $$
begin
  update clients
  set total_pending = coalesce((
    select jsonb_object_agg(currency, total)
    from (
      select currency, sum(greatest(total_amount - amount_paid, 0)) as total
      from projects
      where client_id = p_client_id
      group by currency
      having sum(greatest(total_amount - amount_paid, 0)) > 0
    ) t
  ), '{}'::jsonb)
  where id = p_client_id;
end;
$$;

-- projects -> client's total_pending, kept accurate whenever a
-- project's balance changes (including via the income trigger above,
-- and when a project is created, edited, or deleted directly).
create or replace function fn_project_pending_rollup() returns trigger
language plpgsql as $$
begin
  if tg_op = 'DELETE' then
    perform fn_recompute_client_pending(old.client_id);
  else
    perform fn_recompute_client_pending(new.client_id);
    if tg_op = 'UPDATE' and old.client_id is distinct from new.client_id then
      perform fn_recompute_client_pending(old.client_id);
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_project_pending_rollup on projects;
create trigger trg_project_pending_rollup
after insert or update or delete on projects
for each row execute function fn_project_pending_rollup();

-- work_entries -> client's total_videos_completed + last_activity_at
create or replace function fn_work_entries_rollup() returns trigger
language plpgsql as $$
declare
  v_client_id uuid := coalesce(new.client_id, old.client_id);
  v_before integer := case when tg_op = 'INSERT' then 0 else coalesce(old.video_count, 0) end;
  v_after integer := case when tg_op = 'DELETE' then 0 else coalesce(new.video_count, 0) end;
  v_delta integer := v_after - v_before;
begin
  if v_client_id is not null then
    update clients
    set total_videos_completed = total_videos_completed + v_delta,
        last_activity_at = now()
    where id = v_client_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_work_entries_rollup on work_entries;
create trigger trg_work_entries_rollup
after insert or update or delete on work_entries
for each row execute function fn_work_entries_rollup();

-- New project starts with amount_remaining = total_amount.
create or replace function fn_project_defaults() returns trigger
language plpgsql as $$
begin
  if new.amount_remaining is null or new.amount_remaining = 0 then
    new.amount_remaining := new.total_amount - new.amount_paid;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_project_defaults on projects;
create trigger trg_project_defaults
before insert on projects
for each row execute function fn_project_defaults();

-- One-time backfill: fix any client whose total_pending is currently
-- wrong from the old (buggy) trigger logic, by recomputing it from the
-- real project data. Safe to re-run any time.
do $$
declare
  c record;
begin
  for c in select id from clients loop
    perform fn_recompute_client_pending(c.id);
  end loop;
end;
$$;

-- =====================================================================
-- Stats: efficient server-side aggregates instead of downloading every
-- row to sum on the client (see WorkLog spec §10).
-- =====================================================================
create or replace function get_stats_for_range(p_start timestamptz, p_end timestamptz)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'videosEdited', coalesce((select sum(video_count) from work_entries where date >= p_start and date <= p_end), 0),
    'tasksCompleted', coalesce((select count(*) from work_entries where date >= p_start and date <= p_end and status in ('completed','delivered')), 0),
    'hoursWorked', coalesce((select sum(hours_worked) from work_entries where date >= p_start and date <= p_end), 0),
    'income', coalesce((select jsonb_object_agg(currency, total) from (
        select currency, sum(amount) as total from income where date >= p_start and date <= p_end group by currency
      ) t), '{}'::jsonb),
    'expenses', coalesce((select jsonb_object_agg(currency, total) from (
        select currency, sum(amount) as total from expenses where date >= p_start and date <= p_end group by currency
      ) t), '{}'::jsonb)
  );
$$;

-- =====================================================================
-- Row Level Security
-- =====================================================================
-- This is a personal, single-user app with no login: the Flutter app
-- talks to Supabase using only the public "anon" key (never the
-- service-role key). RLS is enabled with a permissive policy so the
-- anon key can read/write — the anon key itself is the access control
-- for now (keep it out of any public repo). If you publish WorkLog
-- for other people to use later, add Supabase Auth + a `user_id`
-- column on every table and replace these policies with
-- `using (auth.uid() = user_id)` — that is the only structural change
-- needed at that point.
alter table clients enable row level security;
alter table projects enable row level security;
alter table work_entries enable row level security;
alter table income enable row level security;
alter table expenses enable row level security;
alter table reminders enable row level security;
alter table daily_notes enable row level security;

drop policy if exists "worklog anon full access" on clients;
create policy "worklog anon full access" on clients for all using (true) with check (true);
drop policy if exists "worklog anon full access" on projects;
create policy "worklog anon full access" on projects for all using (true) with check (true);
drop policy if exists "worklog anon full access" on work_entries;
create policy "worklog anon full access" on work_entries for all using (true) with check (true);
drop policy if exists "worklog anon full access" on income;
create policy "worklog anon full access" on income for all using (true) with check (true);
drop policy if exists "worklog anon full access" on expenses;
create policy "worklog anon full access" on expenses for all using (true) with check (true);
drop policy if exists "worklog anon full access" on reminders;
create policy "worklog anon full access" on reminders for all using (true) with check (true);
drop policy if exists "worklog anon full access" on daily_notes;
create policy "worklog anon full access" on daily_notes for all using (true) with check (true);

-- =====================================================================
-- Realtime: let the app subscribe to live changes (used for the
-- streaming repositories in lib/features/*/data/*_repository_impl.dart)
-- =====================================================================
-- Idempotent: safe to re-run this file any time (e.g. after a schema
-- update) without erroring on tables already added to the publication.
do $$
declare
  t text;
begin
  foreach t in array array['clients','projects','work_entries','income','expenses','reminders']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end;
$$;


-- =====================================================================
-- Calendar feature removed — drop daily_notes (superseded by nothing;
-- the app no longer has a calendar/journal screen).
-- =====================================================================
drop table if exists daily_notes;

-- =====================================================================
-- GYM MODULE
-- =====================================================================

-- Reusable exercise library — type a name once, it's suggested from
-- then on (same pattern as clients).
create table if not exists exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  muscle_group text not null default 'other', -- chest|back|legs|shoulders|arms|core|cardio|other
  equipment text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists idx_exercises_name on exercises (name);
create index if not exists idx_exercises_muscle_group on exercises (muscle_group);

-- Reusable routine templates ("Push Day") and which exercises belong
-- to each, with suggested target sets/reps.
create table if not exists workout_routines (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists routine_exercises (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references workout_routines (id) on delete cascade,
  exercise_id uuid not null references exercises (id) on delete cascade,
  target_sets integer not null default 3,
  target_reps integer not null default 10,
  order_index integer not null default 0
);
create index if not exists idx_routine_exercises_routine on routine_exercises (routine_id, order_index);

-- An actual logged session on a specific date.
create table if not exists workouts (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid references workout_routines (id) on delete set null,
  name text not null default 'Workout',
  date timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists idx_workouts_date on workouts (date desc);

-- Each individual set logged within a workout.
create table if not exists workout_sets (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references workouts (id) on delete cascade,
  exercise_id uuid not null references exercises (id) on delete cascade,
  set_number integer not null default 1,
  reps integer not null default 0,
  weight numeric not null default 0,
  weight_unit text not null default 'kg', -- kg|lbs
  set_type text not null default 'normal', -- normal|warmup|drop|failure|superset
  rpe numeric,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists idx_workout_sets_workout on workout_sets (workout_id);
create index if not exists idx_workout_sets_exercise on workout_sets (exercise_id, created_at desc);

-- Body weight / measurements over time.
create table if not exists body_stats (
  id uuid primary key default gen_random_uuid(),
  date timestamptz not null default now(),
  weight numeric,
  height_cm numeric check (height_cm is null or height_cm between 50 and 300),
  target_weight_kg numeric
    check (target_weight_kg is null or target_weight_kg between 10 and 500),
  body_fat_pct numeric,
  chest_cm numeric,
  waist_cm numeric,
  arm_cm numeric,
  thigh_cm numeric,
  notes text,
  created_at timestamptz not null default now()
);
alter table body_stats
  add column if not exists height_cm numeric
    check (height_cm is null or height_cm between 50 and 300),
  add column if not exists target_weight_kg numeric
    check (target_weight_kg is null or target_weight_kg between 10 and 500);
create index if not exists idx_body_stats_date on body_stats (date desc);

-- Fitness goals ("Bench Press 100kg", "Lose 5kg", "Workout 4x/week").
create table if not exists gym_goals (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  goal_type text not null default 'custom', -- exercise_weight|body_weight|workout_frequency|custom
  exercise_id uuid references exercises (id) on delete set null,
  target_value numeric not null,
  start_value numeric not null default 0,
  unit text not null default '',
  target_date timestamptz,
  achieved boolean not null default false,
  achieved_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_gym_goals_achieved on gym_goals (achieved);

-- Reusable food library (same type-ahead pattern as exercises/clients).
create table if not exists foods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  unit_label text not null default '100g',
  calories numeric not null default 0,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists idx_foods_name on foods (name);

-- Each meal logged. Macro values are snapshotted at log time (never a
-- live join to `foods`) so editing a food later never rewrites history
-- — same reasoning as income/work_entries elsewhere in this schema.
create table if not exists meal_entries (
  id uuid primary key default gen_random_uuid(),
  date timestamptz not null default now(),
  meal_type text not null default 'snack', -- breakfast|lunch|dinner|snack
  food_id uuid references foods (id) on delete set null,
  food_name text not null,
  quantity numeric not null default 1,
  calories numeric not null default 0,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists idx_meal_entries_date on meal_entries (date desc);

-- Nutrition source metadata and hydration tracking (v4).
alter table foods add column if not exists barcode text;
alter table foods add column if not exists source text not null default 'manual';
create index if not exists idx_foods_barcode on foods (barcode);

create table if not exists water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date date not null default current_date,
  milliliters integer not null default 250 check (milliliters > 0 and milliliters <= 10000),
  created_at timestamptz not null default now()
);
alter table water_logs enable row level security;
drop policy if exists "own water logs" on water_logs;
create policy "own water logs" on water_logs for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create index if not exists idx_water_logs_user_date on water_logs (user_id, date desc);

-- Single-row daily target (personal app — one active target at a time).
create table if not exists diet_targets (
  id integer primary key default 1,
  daily_calories numeric not null default 2200,
  daily_protein numeric not null default 150,
  daily_carbs numeric not null default 220,
  daily_fat numeric not null default 70,
  updated_at timestamptz not null default now(),
  constraint diet_targets_singleton check (id = 1)
);
-- Guarded: on a brand-new install `id` is still the integer(1)
-- singleton declared above, so this seeds it. On a database that has
-- already gone through the "diet_targets -> per-user uuid" migration
-- further down this file, `id` is uuid by the time this file is
-- re-run, and this insert must skip entirely — inserting literal `1`
-- into a uuid column errors, it doesn't just silently no-op.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'diet_targets' and column_name = 'id' and data_type = 'integer'
  ) then
    insert into diet_targets (id) values (1) on conflict (id) do nothing;
  end if;
end;
$$;

-- Personal records are intentionally NOT a stored table — see
-- get_exercise_pr / get_all_prs below. Computing them live from
-- workout_sets means they can never drift out of sync.
create or replace function get_exercise_pr(p_exercise_id uuid)
returns numeric language sql stable as $$
  select max(weight) from workout_sets where exercise_id = p_exercise_id and set_type != 'warmup';
$$;

-- Gym analytics: efficient server-side aggregate instead of pulling
-- every set down to the client to sum (same principle as
-- get_stats_for_range for the work/finance side of the app).
create or replace function get_gym_stats(p_start timestamptz, p_end timestamptz)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'workoutsCompleted', coalesce((select count(*) from workouts where date >= p_start and date <= p_end), 0),
    'totalVolume', coalesce((
      select sum(ws.reps * ws.weight) from workout_sets ws
      join workouts w on w.id = ws.workout_id
      where w.date >= p_start and w.date <= p_end
    ), 0),
    'totalSets', coalesce((
      select count(*) from workout_sets ws
      join workouts w on w.id = ws.workout_id
      where w.date >= p_start and w.date <= p_end
    ), 0),
    'muscleGroups', coalesce((
      select jsonb_object_agg(muscle_group, cnt) from (
        select e.muscle_group, count(*) as cnt
        from workout_sets ws
        join workouts w on w.id = ws.workout_id
        join exercises e on e.id = ws.exercise_id
        where w.date >= p_start and w.date <= p_end
        group by e.muscle_group
      ) t
    ), '{}'::jsonb)
  );
$$;

alter table exercises enable row level security;
alter table workout_routines enable row level security;
alter table routine_exercises enable row level security;
alter table workouts enable row level security;
alter table workout_sets enable row level security;
alter table body_stats enable row level security;
alter table gym_goals enable row level security;
alter table foods enable row level security;
alter table meal_entries enable row level security;
alter table diet_targets enable row level security;

drop policy if exists "worklog anon full access" on exercises;
create policy "worklog anon full access" on exercises for all using (true) with check (true);
drop policy if exists "worklog anon full access" on workout_routines;
create policy "worklog anon full access" on workout_routines for all using (true) with check (true);
drop policy if exists "worklog anon full access" on routine_exercises;
create policy "worklog anon full access" on routine_exercises for all using (true) with check (true);
drop policy if exists "worklog anon full access" on workouts;
create policy "worklog anon full access" on workouts for all using (true) with check (true);
drop policy if exists "worklog anon full access" on workout_sets;
create policy "worklog anon full access" on workout_sets for all using (true) with check (true);
drop policy if exists "worklog anon full access" on body_stats;
create policy "worklog anon full access" on body_stats for all using (true) with check (true);
drop policy if exists "worklog anon full access" on gym_goals;
create policy "worklog anon full access" on gym_goals for all using (true) with check (true);
drop policy if exists "worklog anon full access" on foods;
create policy "worklog anon full access" on foods for all using (true) with check (true);
drop policy if exists "worklog anon full access" on meal_entries;
create policy "worklog anon full access" on meal_entries for all using (true) with check (true);
drop policy if exists "worklog anon full access" on diet_targets;
create policy "worklog anon full access" on diet_targets for all using (true) with check (true);

do $$
declare
  t text;
begin
  foreach t in array array['exercises','workout_routines','routine_exercises','workouts','workout_sets','body_stats','gym_goals','foods','meal_entries','diet_targets']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table %I', t);
    end if;
  end loop;
end;
$$;

-- =====================================================================
-- PUBLIC INVOICE SHARING
-- =====================================================================
-- A project can be shared via an unguessable link. The token is
-- unrelated to the project's real id (never expose that), and the
-- lookup function below is `security definer` — it runs with elevated
-- rights internally but only ever returns a hand-picked, safe subset
-- of fields for the one matching project. The public invoice page
-- calls ONLY this function with the anon key; it never queries the
-- `projects`/`clients` tables directly, so that anon key can't be used
-- to browse any other data even if someone inspects the page's
-- network requests.
alter table projects add column if not exists share_token uuid unique default gen_random_uuid();

create or replace function get_public_invoice(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'projectTitle', p.title,
    'clientName', c.name,
    'totalAmount', p.total_amount,
    'amountPaid', p.amount_paid,
    'amountRemaining', p.amount_remaining,
    'currency', p.currency,
    'status', p.status,
    'dueDate', p.due_date,
    'createdAt', p.created_at
  )
  into result
  from projects p
  join clients c on c.id = p.client_id
  where p.share_token = p_token;

  return result; -- null if the token doesn't match anything
end;
$$;

-- Explicitly allow the anon (public) role to call this one function —
-- everything else stays governed by the RLS policies above, which the
-- public invoice page never touches.
grant execute on function get_public_invoice(uuid) to anon;

-- =====================================================================
-- MULTI-USER AUTH + DATA ISOLATION
-- =====================================================================
-- Every table gets a user_id column defaulting to auth.uid(), so
-- existing insert code (which never sets user_id explicitly) keeps
-- working unchanged — Postgres fills it in automatically from the
-- authenticated session. RLS policies then enforce that a user can
-- only ever see/touch their own rows, at the database level (not
-- just hidden in the UI) — this holds even if someone bypasses the
-- app entirely and queries the API directly.

-- If you ran reset_data.sql first (or these tables are already
-- empty), this is the simple, direct version: every row from now on
-- must have an owner, filled in automatically from whoever is logged
-- into the app. If any table still has existing rows with no owner,
-- this raises a clear NOTICE naming that table instead of a hard
-- error — run reset_data.sql (or manually clear that table) and
-- re-run this file.
do $$
declare
  t text;
  remaining_nulls integer;
begin
  foreach t in array array[
    'clients','projects','work_entries','income','expenses','reminders',
    'exercises','workout_routines','routine_exercises','workouts','workout_sets',
    'body_stats','gym_goals','foods','meal_entries','diet_targets'
  ]
  loop
    if not exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name = t and column_name = 'user_id'
    ) then
      execute format('alter table %I add column user_id uuid references auth.users(id) on delete cascade', t);
      execute format('create index if not exists idx_%s_user_id on %I (user_id)', t, t);
    end if;

    execute format('select count(*) from %I where user_id is null', t) into remaining_nulls;

    if remaining_nulls = 0 then
      execute format('alter table %I alter column user_id set default auth.uid()', t);
      execute format('alter table %I alter column user_id set not null', t);
    else
      raise notice 'Table % has % existing row(s) with no owner — run reset_data.sql, or manually assign/delete them, then re-run this file.', t, remaining_nulls;
    end if;
  end loop;
end;
$$;

-- Simple profile table: just a display name, used on generated PDFs
-- ("User name") and anywhere the app shows "you" rather than an email.
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);
alter table profiles enable row level security;
drop policy if exists "own profile only" on profiles;
create policy "own profile only" on profiles for all
  using (auth.uid() = id) with check (auth.uid() = id);

-- Auto-create a profile row the moment someone signs up.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)));
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Replace every "anyone with the anon key" policy with per-user
-- isolation. Re-running this file is safe — policies are dropped and
-- recreated each time.
do $$
declare
  t text;
begin
  foreach t in array array[
    'clients','projects','work_entries','income','expenses','reminders',
    'exercises','workout_routines','routine_exercises','workouts','workout_sets',
    'body_stats','gym_goals','foods','meal_entries','diet_targets'
  ]
  loop
    execute format('drop policy if exists "worklog anon full access" on %I', t);
    execute format('drop policy if exists "own rows only" on %I', t);
    execute format(
      'create policy "own rows only" on %I for all using (auth.uid() = user_id) with check (auth.uid() = user_id)',
      t
    );
  end loop;
end;
$$;

-- foods/exercises were previously a single shared library across
-- everyone (since there was only one "user"). Each user now gets
-- their own — this is a side effect of adding per-row user_id above,
-- and is the correct behavior for genuine multi-user isolation.

-- diet_targets was a single-row table (id=1) back when there was
-- only one user. Now that user_id exists, each user needs their own
-- target row, keyed by user_id instead of a fixed id. Guarded as one
-- block (not just the rename) so re-running this file after the
-- migration has already happened is a clean no-op — otherwise
-- `add column if not exists id2` would add a stray extra column every
-- time, since the original id2 no longer exists under that name once
-- it's been renamed to id.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'diet_targets' and column_name = 'id' and data_type = 'integer'
  ) then
    alter table diet_targets drop constraint if exists diet_targets_pkey;
    alter table diet_targets drop constraint if exists diet_targets_singleton;
    alter table diet_targets add column id2 uuid default gen_random_uuid();
    alter table diet_targets drop column id;
    alter table diet_targets rename column id2 to id;
    alter table diet_targets add primary key (id);
    alter table diet_targets add constraint diet_targets_user_unique unique (user_id);
  end if;
end;
$$;

-- =====================================================================
-- Invoice PDF support: track when a project was last edited.
-- =====================================================================
alter table projects add column if not exists updated_at timestamptz not null default now();

create or replace function fn_touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_projects_touch_updated_at on projects;
create trigger trg_projects_touch_updated_at
before update on projects
for each row execute function fn_touch_updated_at();

-- =====================================================================
-- V2 — PROFILE SETTINGS, ONBOARDING, GYM TOGGLE, ACCOUNT DELETION
-- Safe to re-run. Run the whole file again after updating the app.
-- =====================================================================

-- Profile columns that drive the Profile tab, onboarding and nav.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'onboarding_done'
  ) then
    alter table profiles add column onboarding_done boolean not null default false;
    alter table profiles add column gym_enabled boolean not null default false;
    -- Accounts that existed BEFORE this update already used the app
    -- (and its Gym tab): skip onboarding and keep Gym visible for them.
    update profiles set onboarding_done = true, gym_enabled = true;
  end if;
end;
$$;

alter table profiles add column if not exists default_currency text not null default 'PKR';
alter table profiles add column if not exists invoice_name text;            -- name printed on invoices/reports
alter table profiles add column if not exists avatar_url text;
alter table profiles add column if not exists avatar_path text;             -- owned Storage object path, not external OAuth images
alter table profiles add column if not exists payment_instructions text;    -- default text printed on invoice PDFs
alter table profiles add column if not exists updated_at timestamptz not null default now();
alter table profiles add column if not exists phone text;
alter table profiles add column if not exists professional_title text;
alter table profiles add column if not exists business_name text;
alter table profiles add column if not exists location text;
alter table profiles add column if not exists website text;
alter table profiles add column if not exists country text;
alter table profiles add column if not exists age_range text;
alter table profiles add column if not exists gender text;
alter table profiles add column if not exists date_of_birth date;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_age_range_allowed') then
    alter table public.profiles add constraint profiles_age_range_allowed
      check (age_range is null or age_range in ('18_24', '25_34', '35_44', '45_54', '55_plus'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.profiles'::regclass and conname = 'profiles_country_length') then
    alter table public.profiles add constraint profiles_country_length
      check (country is null or length(trim(country)) between 1 and 80);
  end if;
end;
$$;

alter table public.profiles drop constraint if exists profiles_gender_allowed;
alter table public.profiles add constraint profiles_gender_allowed
  check (gender is null or gender in
    ('woman', 'man', 'non_binary', 'prefer_not_to_say'));

comment on column public.profiles.country is
  'Self-reported country for aggregate product-usage analysis.';
comment on column public.profiles.age_range is
  'Legacy self-reported age band retained for existing profiles.';
comment on column public.profiles.gender is
  'Self-reported gender for aggregate product-usage analysis.';
comment on column public.profiles.date_of_birth is
  'Date of birth collected during onboarding; age is calculated in the client and the value is immutable after it is set.';

create or replace function public.protect_profile_demographics()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.date_of_birth is not null and new.date_of_birth > current_date then
    raise exception 'Date of birth cannot be in the future';
  end if;
  if old.date_of_birth is not null
     and new.date_of_birth is distinct from old.date_of_birth then
    raise exception 'Date of birth cannot be changed after onboarding';
  end if;
  if old.gender is not null and new.gender is distinct from old.gender then
    raise exception 'Gender cannot be changed after onboarding';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_demographics_immutable on public.profiles;
create trigger profiles_demographics_immutable
before update on public.profiles
for each row execute function public.protect_profile_demographics();

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
grant select, insert, update on table public.finance_activity_dismissals to authenticated;
grant usage on schema public to supabase_auth_admin;
grant delete on table public.finance_activity_dismissals to supabase_auth_admin;
drop policy if exists "Users can read own finance activity dismissals" on public.finance_activity_dismissals;
create policy "Users can read own finance activity dismissals"
  on public.finance_activity_dismissals for select to authenticated
  using ((select auth.uid()) = user_id);
drop policy if exists "Users can create own finance activity dismissals" on public.finance_activity_dismissals;
create policy "Users can create own finance activity dismissals"
  on public.finance_activity_dismissals for insert to authenticated
  with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update own finance activity dismissals" on public.finance_activity_dismissals;
create policy "Users can update own finance activity dismissals"
  on public.finance_activity_dismissals for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

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

-- Profile row is created on signup. Works for email/password AND Google
-- (Google puts the name in full_name / name and the photo in picture).
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      split_part(new.email, '@', 1)
    ),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Live updates for the Profile row (so toggling Gym rebuilds the nav
-- instantly, on every signed-in device).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table profiles;
  end if;
end;
$$;

-- Security-action challenges are inaccessible to client roles. The
-- account-security Edge Function verifies Supabase's email recovery OTP,
-- then receives an action-bound, one-use ticket from these RPCs.
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
  p_email text, p_action text, p_requested_at timestamptz
) returns void
language plpgsql security definer set search_path = pg_catalog, private as $$
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
  p_email text, p_action text, p_user_id uuid, p_ticket_hash text
) returns boolean
language plpgsql security definer set search_path = pg_catalog, private as $$
begin
  if p_ticket_hash is null or length(p_ticket_hash) <> 64 then return false; end if;
  update private.auth_action_challenges
  set user_id = p_user_id, ticket_hash = p_ticket_hash
  where email = lower(trim(p_email)) and action = p_action
    and requested_at <= clock_timestamp() and expires_at > clock_timestamp()
    and user_id is null and ticket_hash is null and consumed_at is null;
  return found;
end;
$$;

create or replace function public.consume_auth_action_ticket(
  p_email text, p_action text, p_ticket_hash text, p_expected_user_id uuid default null
) returns uuid
language plpgsql security definer set search_path = pg_catalog, private as $$
declare v_user_id uuid;
begin
  update private.auth_action_challenges
  set consumed_at = clock_timestamp()
  where email = lower(trim(p_email)) and action = p_action
    and ticket_hash = p_ticket_hash and ticket_hash is not null
    and consumed_at is null and expires_at > clock_timestamp()
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

-- Retire the former authenticated-only deletion RPC, which had no OTP gate.
create or replace function public.delete_my_account() returns void
language plpgsql security invoker set search_path = pg_catalog as $$
begin
  raise exception 'Account deletion requires a verified email code';
end;
$$;
revoke all on function public.delete_my_account() from public, anon, authenticated, service_role;

-- OPTIONAL (not urgent for launch): clean up accounts that never
-- verified their email after 30 days. Needs the pg_cron extension
-- (Dashboard -> Database -> Extensions). Uncomment to enable.
-- select cron.schedule('purge-unverified-users', '0 3 * * *', $$
--   delete from auth.users
--   where email_confirmed_at is null and created_at < now() - interval '30 days'
-- $$);

-- SANITY CHECK: this should return ZERO rows (every public table must
-- have Row Level Security enabled).
-- select tablename from pg_tables
-- where schemaname = 'public' and rowsecurity = false;

-- =====================================================================
-- AVATAR STORAGE — Profile tab photo upload
-- =====================================================================
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatar public read" on storage.objects;
create policy "avatar public read" on storage.objects
  for select using (bucket_id = 'avatars');

-- Each user may only write inside a folder named after their own uid
-- (path is "<uid>/avatar.<ext>"), enforced via the folder-name check.
drop policy if exists "avatar owner write" on storage.objects;
create policy "avatar owner write" on storage.objects
  for insert with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatar owner update" on storage.objects;
create policy "avatar owner update" on storage.objects
  for update using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatar owner delete" on storage.objects;
create policy "avatar owner delete" on storage.objects
  for delete using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- =====================================================================
-- V3 — TIME TRACKING, RECURRING (RETAINER) INVOICES, LATE-PAYMENT
-- REMINDERS. Safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Time tracking: a Start/Stop timer on a work entry. NULL = not
-- running. hours_worked is only ever incremented when the timer is
-- stopped — starting/stopping never overwrites a manually-typed value.
-- ---------------------------------------------------------------------
alter table work_entries add column if not exists timer_started_at timestamptz;

-- ---------------------------------------------------------------------
-- Recurring invoices for retainer clients.
-- ---------------------------------------------------------------------
alter table clients add column if not exists is_retainer boolean not null default false;
alter table clients add column if not exists retainer_amount bigint;
alter table clients add column if not exists retainer_currency text;
alter table clients add column if not exists retainer_day_of_month integer; -- 1-28, kept <=28 so every month has that day
alter table clients add column if not exists retainer_last_generated_month text; -- 'YYYY-MM', prevents double-billing

-- Creates one new project (invoice) for every retainer client whose
-- billing day has arrived and hasn't already been billed this
-- calendar month — across ALL users, so this same function works
-- whether it's called from the app (best-effort, on Home launch) or
-- from an optional pg_cron schedule (server-side, works even if the
-- app is never opened that day). `security definer` is required for
-- the cron path, which has no authenticated user in scope; called
-- from the app it simply does a little more (harmless, no data is
-- returned to the caller either way) rather than needing a second
-- near-duplicate function.
create or replace function generate_due_retainer_invoices() returns integer
language plpgsql security definer set search_path = public as $$
declare
  c record;
  v_month text := to_char(now(), 'YYYY-MM');
  v_count integer := 0;
begin
  for c in
    select * from clients
    where is_retainer = true
      and retainer_amount is not null
      and retainer_amount > 0
      and retainer_day_of_month is not null
      and extract(day from now()) >= retainer_day_of_month
      and coalesce(retainer_last_generated_month, '') <> v_month
  loop
    insert into projects (client_id, title, total_amount, currency, due_date, user_id)
    values (
      c.id,
      'Retainer — ' || to_char(now(), 'FMMonth YYYY'),
      c.retainer_amount,
      coalesce(c.retainer_currency, 'PKR'),
      now() + interval '7 days',
      c.user_id
    );
    update clients set retainer_last_generated_month = v_month where id = c.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke all on function generate_due_retainer_invoices() from public, anon;
grant execute on function generate_due_retainer_invoices() to authenticated;

-- ---------------------------------------------------------------------
-- Late payment reminders. Overdue itself is computed live (due_date in
-- the past + not fully paid — see Project.displayStatus in the app),
-- not stored, so there's no row-write moment a trigger could hook
-- into. `overdue_notified_at` is the one piece of state that needs
-- storing: "have we already alerted about this becoming overdue",
-- checked each time the app looks for newly-overdue projects so the
-- same invoice doesn't re-notify every single app open.
-- ---------------------------------------------------------------------
alter table projects add column if not exists overdue_notified_at timestamptz;

create or replace function get_newly_overdue_projects()
returns table (
  id uuid, client_id uuid, client_name text, title text,
  total_amount bigint, amount_remaining bigint, currency text, due_date timestamptz
)
language sql stable as $$
  select p.id, p.client_id, c.name, p.title, p.total_amount, p.amount_remaining, p.currency, p.due_date
  from projects p
  join clients c on c.id = p.client_id
  where p.user_id = auth.uid()
    and p.status <> 'paid'
    and p.due_date is not null
    and p.due_date < now()
    and p.overdue_notified_at is null;
$$;

create or replace function mark_overdue_notified(p_project_id uuid) returns void
language sql as $$
  update projects set overdue_notified_at = now() where id = p_project_id and user_id = auth.uid();
$$;

-- OPTIONAL (needs the pg_cron extension — Dashboard -> Database ->
-- Extensions): runs the retainer-invoice generator daily server-side,
-- so it fires even on days nobody opens the app. Uncomment to enable.
-- select cron.schedule('generate-retainer-invoices', '0 3 * * *', $$
--   select generate_due_retainer_invoices();
-- $$);

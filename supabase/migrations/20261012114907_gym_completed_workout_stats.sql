create or replace function get_gym_stats(p_start timestamptz, p_end timestamptz)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'workoutsCompleted', coalesce((
      select count(*) from public.workouts
      where date >= p_start and date <= p_end and completed_at is not null
    ), 0),
    'totalVolume', coalesce((
      select sum(ws.reps * ws.weight)
      from public.workout_sets ws
      join public.workouts w on w.id = ws.workout_id
      where w.date >= p_start and w.date <= p_end and w.completed_at is not null
    ), 0),
    'totalSets', coalesce((
      select count(*)
      from public.workout_sets ws
      join public.workouts w on w.id = ws.workout_id
      where w.date >= p_start and w.date <= p_end and w.completed_at is not null
    ), 0),
    'muscleGroups', coalesce((
      select jsonb_object_agg(muscle_group, cnt) from (
        select e.muscle_group, count(*) as cnt
        from public.workout_sets ws
        join public.workouts w on w.id = ws.workout_id
        join public.exercises e on e.id = ws.exercise_id
        where w.date >= p_start and w.date <= p_end and w.completed_at is not null
        group by e.muscle_group
      ) t
    ), '{}'::jsonb)
  );
$$;

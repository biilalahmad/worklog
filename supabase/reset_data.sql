-- Run this FIRST if you want to wipe all existing data (e.g. the old
-- single-user test data) and start completely fresh with real
-- multi-user accounts. Safe to run even if some of these tables don't
-- exist yet or are already empty.

truncate table
  income, expenses, work_entries, projects, clients, reminders,
  workout_sets, workouts, routine_exercises, workout_routines,
  body_stats, gym_goals, meal_entries, foods, diet_targets, exercises
cascade;

-- Add optional height and goal snapshots to Gym body-stat history.
-- Existing rows stay valid and null until users choose to record these values.
alter table public.body_stats
  add column if not exists height_cm numeric
    check (height_cm is null or height_cm between 50 and 300),
  add column if not exists target_weight_kg numeric
    check (target_weight_kg is null or target_weight_kg between 10 and 500);

-- Pin search paths for the functions changed in the latest release.
alter function public.get_gym_stats(timestamptz, timestamptz)
  set search_path = public, pg_temp;

alter function public.fn_income_rollup()
  set search_path = public, pg_temp;

alter function public.fn_project_defaults()
  set search_path = public, pg_temp;

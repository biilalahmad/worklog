-- Keep the app-owned object path separately from the public URL.  URLs may
-- come from Google or another identity provider and must never be deleted.
alter table public.profiles
  add column if not exists avatar_path text;

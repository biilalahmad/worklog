alter table public.profiles
  add column if not exists date_of_birth date;

alter table public.profiles
  drop constraint if exists profiles_gender_allowed;

alter table public.profiles
  add constraint profiles_gender_allowed
  check (gender is null or gender in
    ('woman', 'man', 'non_binary', 'prefer_not_to_say'));

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

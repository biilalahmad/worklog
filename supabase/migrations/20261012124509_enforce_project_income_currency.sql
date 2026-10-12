-- A project balance is denominated in the project's currency. Reject linked
-- income in a different currency rather than mixing unlike monetary units.
create or replace function public.fn_validate_project_income_currency()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_project_currency text;
begin
  if new.project_id is null then
    return new;
  end if;

  select upper(currency)
    into v_project_currency
  from public.projects
  where id = new.project_id
    and user_id = new.user_id;

  -- If the project does not belong to this user, leave the existing foreign
  -- key/RLS checks to reject the record without disclosing another user row.
  if v_project_currency is null then
    return new;
  end if;

  if upper(new.currency) is distinct from v_project_currency then
    raise exception 'Income project currency mismatch.'
      using errcode = '23514',
            constraint = 'income_project_currency_matches';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_project_income_currency on public.income;
create trigger trg_validate_project_income_currency
before insert or update on public.income
for each row execute function public.fn_validate_project_income_currency();

revoke all on function public.fn_validate_project_income_currency() from public;

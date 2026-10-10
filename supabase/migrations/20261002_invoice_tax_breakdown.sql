-- Mirrors the production invoice tax migration.
alter table public.projects
  add column if not exists subtotal_amount bigint,
  add column if not exists tax_amount bigint not null default 0,
  add column if not exists tax_rate_bps integer not null default 0
    check (tax_rate_bps between 0 and 100000),
  add column if not exists tax_label text not null default 'Tax';

update public.projects set subtotal_amount = total_amount where subtotal_amount is null;
alter table public.projects alter column subtotal_amount set default 0;
alter table public.projects alter column subtotal_amount set not null;

create or replace function public.fn_project_tax_amounts()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' and new.subtotal_amount = 0
     and coalesce(new.total_amount, 0) <> 0
     and coalesce(new.tax_rate_bps, 0) = 0 then
    new.subtotal_amount := new.total_amount;
  end if;
  new.tax_amount := round(new.subtotal_amount * new.tax_rate_bps / 10000.0)::bigint;
  new.total_amount := new.subtotal_amount + new.tax_amount;
  return new;
end;
$$;

drop trigger if exists trg_projects_calculate_tax on public.projects;
create trigger trg_projects_calculate_tax
before insert or update of subtotal_amount, tax_rate_bps on public.projects
for each row execute function public.fn_project_tax_amounts();

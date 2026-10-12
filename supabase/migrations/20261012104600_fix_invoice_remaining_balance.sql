-- Keep invoice balances non-negative when recorded payments exceed the quote.
-- The payment history is retained; this only fixes derived amount-due values.
create or replace function public.fn_income_rollup()
returns trigger
language plpgsql
as $$
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
    update public.clients
    set total_earned = public.jsonb_currency_add(total_earned, v_currency, v_delta),
        last_activity_at = now()
    where id = v_client_id;
  end if;

  if v_project_id is not null and v_delta <> 0 then
    select total_amount, amount_paid
    into v_total, v_paid
    from public.projects
    where id = v_project_id
    for update;
    if found then
      v_paid := coalesce(v_paid, 0) + v_delta;
      v_remaining := greatest(v_total - v_paid, 0);
      v_status := case
        when v_paid <= 0 then 'unpaid'
        when v_remaining = 0 then 'paid'
        else 'partiallyPaid'
      end;
      update public.projects
      set amount_paid = v_paid,
          amount_remaining = v_remaining,
          status = v_status
      where id = v_project_id;
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function public.fn_project_defaults()
returns trigger
language plpgsql
as $$
begin
  if new.amount_remaining is null or new.amount_remaining = 0 then
    new.amount_remaining := greatest(new.total_amount - new.amount_paid, 0);
  end if;
  return new;
end;
$$;

create or replace function public.get_public_invoice(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'projectTitle', p.title,
    'clientName', c.name,
    'subtotalAmountMinor', p.subtotal_amount,
    'taxAmountMinor', p.tax_amount,
    'taxRateBps', p.tax_rate_bps,
    'taxLabel', p.tax_label,
    'totalAmountMinor', p.total_amount,
    'amountPaidMinor', p.amount_paid,
    'amountRemainingMinor', greatest(p.total_amount - p.amount_paid, 0),
    'totalAmount', p.total_amount,
    'amountPaid', p.amount_paid,
    'amountRemaining', greatest(p.total_amount - p.amount_paid, 0),
    'currency', p.currency,
    'status', p.status,
    'dueDate', p.due_date,
    'createdAt', p.created_at
  )
  into result
  from public.projects p
  join public.clients c on c.id = p.client_id
  where p.share_token = p_token;

  return result;
end;
$$;

revoke all on function public.get_public_invoice(uuid) from public;
grant execute on function public.get_public_invoice(uuid) to anon, authenticated;

-- Repair only stale derived balances. Recorded income/payment rows are untouched.
update public.projects
set amount_remaining = greatest(total_amount - amount_paid, 0)
where amount_remaining is distinct from greatest(total_amount - amount_paid, 0);

-- Keep hosted invoices aligned with the database-maintained project balance.
-- The existing trigger is authoritative; no project/payment rows are changed.
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
    'amountRemainingMinor', greatest(coalesce(p.amount_remaining, p.total_amount - p.amount_paid), 0),
    'totalAmount', p.total_amount,
    'amountPaid', p.amount_paid,
    'amountRemaining', greatest(coalesce(p.amount_remaining, p.total_amount - p.amount_paid), 0),
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

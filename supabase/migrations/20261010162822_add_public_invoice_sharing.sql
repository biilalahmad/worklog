-- Public invoice sharing exposes only these selected project/client fields
-- through one unpredictable token. Public roles cannot query source tables.
alter table public.projects
  add column if not exists share_token uuid unique default gen_random_uuid();

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
    'totalAmount', p.total_amount,
    'amountPaid', p.amount_paid,
    'amountRemaining', p.amount_remaining,
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

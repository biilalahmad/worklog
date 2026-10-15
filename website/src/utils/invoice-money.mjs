/** Format integer currency minor units (cents/paisa) at the display edge. */
export function formatInvoiceMoney(minorUnits, currency, locale) {
  const amount = Number(minorUnits);
  const code = typeof currency === 'string' ? currency.toUpperCase() : '';
  if (!Number.isSafeInteger(amount) || !/^[A-Z]{3}$/.test(code)) return '—';

  try {
    const currencyFormatter = new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: code,
    });
    // Keep PKR's two minor-unit digits explicit. Some browser/locale ICU data
    // has shipped PKR with inconsistent currency precision; deriving the
    // divisor from that data can multiply paisa/rupees by 100 on public pages.
    const fractionDigits = code === 'PKR'
      ? 2
      : currencyFormatter.resolvedOptions().maximumFractionDigits;
    const scale = 10 ** fractionDigits;
    return new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: code,
      minimumFractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
    }).format(amount / scale);
  } catch {
    return `${code} ${(amount / 100).toFixed(2)}`;
  }
}

/** Accept the explicit API contract and its pre-migration field names. */
export function normalizePublicInvoice(invoice) {
  const readMinor = (field, legacyField) =>
    Number(invoice[field] ?? (legacyField ? invoice[legacyField] : undefined) ?? 0);
  const totalAmountMinor = readMinor('totalAmountMinor', 'totalAmount');
  const amountPaidMinor = readMinor('amountPaidMinor', 'amountPaid');
  const storedRemaining = invoice.amountRemainingMinor ?? invoice.amountRemaining;
  const amountRemainingMinor = storedRemaining == null
    ? Math.max(0, totalAmountMinor - amountPaidMinor)
    : Math.min(totalAmountMinor, Math.max(0, Number(storedRemaining)));

  return {
    ...invoice,
    subtotalAmountMinor: readMinor('subtotalAmountMinor', 'totalAmount'),
    taxAmountMinor: readMinor('taxAmountMinor'),
    taxRateBps: readMinor('taxRateBps'),
    totalAmountMinor,
    amountPaidMinor,
    // Use the backend's trigger-maintained outstanding balance when present;
    // older payloads fall back to total minus paid. Never show a negative due.
    amountRemainingMinor,
  };
}

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
    const fractionDigits = currencyFormatter.resolvedOptions().maximumFractionDigits;
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

  return {
    ...invoice,
    subtotalAmountMinor: readMinor('subtotalAmountMinor', 'totalAmount'),
    taxAmountMinor: readMinor('taxAmountMinor'),
    taxRateBps: readMinor('taxRateBps'),
    totalAmountMinor,
    amountPaidMinor,
    // The stored rollup can be stale, or negative for historical overpayment.
    // A customer-facing invoice must never show a negative amount due.
    amountRemainingMinor: Math.max(0, totalAmountMinor - amountPaidMinor),
  };
}

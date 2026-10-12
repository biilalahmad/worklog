import test from 'node:test';
import assert from 'node:assert/strict';
import { formatInvoiceMoney, normalizePublicInvoice } from '../src/utils/invoice-money.mjs';
import { downloadInvoicePdf } from '../src/utils/invoice-pdf.mjs';

test('formats major-currency examples from integer minor units', () => {
  const cases = [
    [10000, 'USD', '$100.00'],
    [50, 'USD', '$0.50'],
    [199999, 'USD', '$1,999.99'],
    [100000000, 'USD', '$1,000,000.00'],
  ];

  for (const [minor, currency, expected] of cases) {
    assert.equal(formatInvoiceMoney(minor, currency, 'en-US'), expected);
  }
});

test('uses the ISO currency precision for zero-decimal currencies', () => {
  assert.equal(formatInvoiceMoney(10000, 'JPY', 'en-US'), '¥10,000');
});

test('normalizes public invoice totals without changing their minor-unit values', () => {
  const invoice = normalizePublicInvoice({
    subtotalAmountMinor: 10000,
    taxAmountMinor: 500,
    taxRateBps: 500,
    totalAmountMinor: 10500,
    amountPaidMinor: 2500,
    amountRemainingMinor: 8000,
    currency: 'USD',
  });

  assert.equal(invoice.subtotalAmountMinor, 10000);
  assert.equal(invoice.taxAmountMinor, 500);
  assert.equal(invoice.totalAmountMinor, 10500);
  assert.equal(invoice.amountPaidMinor, 2500);
  assert.equal(invoice.amountRemainingMinor, 8000);
  assert.equal(formatInvoiceMoney(invoice.totalAmountMinor, invoice.currency, 'en-US'), '$105.00');
});

test('legacy public invoice amount fields are also treated as minor units', () => {
  const invoice = normalizePublicInvoice({
    totalAmount: 10000,
    amountPaid: 5000,
    amountRemaining: 5000,
  });

  assert.equal(formatInvoiceMoney(invoice.totalAmountMinor, 'USD', 'en-US'), '$100.00');
  assert.equal(formatInvoiceMoney(invoice.amountPaidMinor, 'USD', 'en-US'), '$50.00');
});

test('an overpaid invoice never displays a negative amount due', () => {
  const invoice = normalizePublicInvoice({
    totalAmountMinor: 10000,
    amountPaidMinor: 20000,
    amountRemainingMinor: -10000,
    currency: 'EUR',
  });

  assert.equal(invoice.amountRemainingMinor, 0);
  assert.equal(formatInvoiceMoney(invoice.amountRemainingMinor, 'EUR', 'en-US'), '€0.00');
});

test('uses the server-calculated outstanding balance when it differs from arithmetic', () => {
  const invoice = normalizePublicInvoice({
    totalAmountMinor: 10000,
    amountPaidMinor: 6000,
    amountRemainingMinor: 3200,
    currency: 'PKR',
  });

  assert.equal(invoice.amountRemainingMinor, 3200);
  assert.equal(formatInvoiceMoney(invoice.amountRemainingMinor, 'PKR', 'en-PK'), 'Rs 32.00');
});

test('downloads a real PDF blob with the invoice line item and amount contract', () => {
  let downloadedName = '';
  let removed = false;
  const link = {
    click() { downloadedName = this.download; },
    remove() { removed = true; },
  };
  const documentRef = {
    body: { append() {} },
    createElement() { return link; },
  };
  const urlApi = {
    createObjectURL(blob) {
      assert.equal(blob.type, 'application/pdf');
      return 'blob:invoice-preview';
    },
    revokeObjectURL(url) { assert.equal(url, 'blob:invoice-preview'); },
  };
  const fileName = downloadInvoicePdf({
    projectTitle: 'Editing work',
    clientName: 'Amina',
    subtotalAmountMinor: 10000,
    taxAmountMinor: 0,
    taxRateBps: 0,
    totalAmountMinor: 10000,
    amountPaidMinor: 0,
    amountRemainingMinor: 10000,
    currency: 'USD',
    status: 'unpaid',
    createdAt: '2026-10-11T00:00:00Z',
  }, { documentRef, urlApi });

  assert.equal(fileName, 'WorkLog-Invoice-2026-10-11.pdf');
  assert.equal(downloadedName, fileName);
  assert.equal(removed, true);
});

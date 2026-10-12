import { jsPDF } from 'jspdf';
import { formatInvoiceMoney } from './invoice-money.mjs';

const navy = [24, 59, 98];
const ink = [27, 42, 65];
const muted = [95, 113, 137];
const line = [220, 229, 239];

function wrapped(pdf, value, x, y, width, lineHeight = 5) {
  const lines = pdf.splitTextToSize(String(value || '—'), width);
  pdf.text(lines, x, y);
  return y + lines.length * lineHeight;
}

function safeDate(value) {
  if (typeof value !== 'string' || !value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? '—' : new Intl.DateTimeFormat('en', { dateStyle: 'medium' }).format(date);
}

/** Build and download a real PDF file from the public invoice data. */
export function downloadInvoicePdf(invoice, { documentRef = document, urlApi = URL } = {}) {
  const pdf = new jsPDF({ unit: 'mm', format: 'a4' });
  const pageWidth = pdf.internal.pageSize.getWidth();
  const left = 20;
  const right = pageWidth - 20;
  const width = right - left;
  const currency = invoice.currency;
  const datePart = typeof invoice.createdAt === 'string'
    ? invoice.createdAt.slice(0, 10)
    : 'invoice';
  const fileName = `WorkLog-Invoice-${datePart}.pdf`;
  let y = 23;

  pdf.setTextColor(...navy);
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(16);
  pdf.text('WorkLog', left, y);
  pdf.setFontSize(22);
  pdf.text('INVOICE', right, y, { align: 'right' });
  y += 12;
  pdf.setDrawColor(...line);
  pdf.line(left, y, right, y);
  y += 10;

  pdf.setTextColor(...muted);
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(8);
  pdf.text('INVOICE DATE', left, y);
  pdf.text('STATUS', right, y, { align: 'right' });
  y += 6;
  pdf.setTextColor(...ink);
  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(10);
  pdf.text(safeDate(invoice.createdAt), left, y);
  pdf.text(String(invoice.status || '—').replaceAll('_', ' '), right, y, { align: 'right' });
  y += 12;

  pdf.setTextColor(...muted);
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(8);
  pdf.text('FROM', left, y);
  pdf.text('BILL TO', left + width / 2, y);
  y += 6;
  pdf.setTextColor(...ink);
  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(10);
  pdf.text('WorkLog user', left, y);
  y = wrapped(pdf, invoice.clientName, left + width / 2, y, width / 2 - 4, 5);
  y += 10;

  const descriptionX = left;
  const qtyX = left + width * 0.59;
  const rateX = left + width * 0.7;
  const amountX = right;
  pdf.setFillColor(...navy);
  pdf.rect(left, y - 5, width, 10, 'F');
  pdf.setTextColor(255, 255, 255);
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(8);
  pdf.text('DESCRIPTION', descriptionX + 3, y + 1);
  pdf.text('QTY', qtyX, y + 1, { align: 'right' });
  pdf.text('RATE', rateX + 20, y + 1, { align: 'right' });
  pdf.text('AMOUNT', amountX - 3, y + 1, { align: 'right' });
  y += 17;

  pdf.setTextColor(...ink);
  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(9);
  y = wrapped(pdf, invoice.projectTitle, descriptionX + 3, y, width * 0.5, 5);
  pdf.text('1', qtyX, y - 5, { align: 'right' });
  pdf.text(formatInvoiceMoney(invoice.subtotalAmountMinor, currency, 'en'), rateX + 20, y - 5, { align: 'right' });
  pdf.text(formatInvoiceMoney(invoice.subtotalAmountMinor, currency, 'en'), amountX - 3, y - 5, { align: 'right' });
  y += 3;
  pdf.setDrawColor(...line);
  pdf.line(left, y, right, y);
  y += 11;

  const summaryX = left + width * 0.52;
  const labelX = summaryX;
  const valueX = right;
  const row = (label, value, bold = false) => {
    pdf.setTextColor(...(bold ? navy : muted));
    pdf.setFont('helvetica', bold ? 'bold' : 'normal');
    pdf.setFontSize(bold ? 11 : 9);
    pdf.text(label, labelX, y);
    pdf.text(value, valueX, y, { align: 'right' });
    y += bold ? 8 : 7;
  };
  row('Subtotal', formatInvoiceMoney(invoice.subtotalAmountMinor, currency, 'en'));
  if (Number(invoice.taxAmountMinor) !== 0) {
    const rate = Number(invoice.taxRateBps) / 100;
    const taxLabel = `${invoice.taxLabel || 'Tax'}${rate ? ` (${rate.toFixed(2)}%)` : ''}`;
    row(taxLabel, formatInvoiceMoney(invoice.taxAmountMinor, currency, 'en'));
  }
  pdf.setDrawColor(...line);
  pdf.line(summaryX, y - 2, right, y - 2);
  y += 4;
  row('Total', formatInvoiceMoney(invoice.totalAmountMinor, currency, 'en'), true);
  y += 2;
  row('Paid', formatInvoiceMoney(invoice.amountPaidMinor, currency, 'en'));
  row('Amount due', formatInvoiceMoney(invoice.amountRemainingMinor, currency, 'en'), true);

  if (invoice.dueDate) {
    y += 8;
    pdf.setTextColor(...muted);
    pdf.setFont('helvetica', 'normal');
    pdf.setFontSize(9);
    pdf.text(`Due ${safeDate(invoice.dueDate)}. Please contact the sender if you have a question about payment.`, left, y, { maxWidth: width });
  }

  const blob = pdf.output('blob');
  const blobUrl = urlApi.createObjectURL(blob);
  const link = documentRef.createElement('a');
  link.href = blobUrl;
  link.download = fileName;
  link.hidden = true;
  documentRef.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => urlApi.revokeObjectURL(blobUrl), 1000);
  return fileName;
}

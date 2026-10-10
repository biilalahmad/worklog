import test from 'node:test';
import assert from 'node:assert/strict';
import { createContactHandler } from '../../netlify/functions/contact.mjs';

const makeRequest = (body, { method = 'POST', ip = '127.0.0.1' } = {}) => new Request('https://worklog.test/.netlify/functions/contact', {
  method,
  headers: { 'content-type': 'application/json', 'x-nf-client-connection-ip': ip },
  body: method === 'POST' ? JSON.stringify(body) : undefined,
});

test('rejects non-POST requests', async () => {
  const response = await createContactHandler()(makeRequest({}, { method: 'GET' }));
  assert.equal(response.status, 405);
  assert.equal(response.headers.get('allow'), 'POST');
});

test('validates support form fields', async () => {
  const response = await createContactHandler()(makeRequest({ name: '', email: 'bad', topic: '', message: 'short' }));
  assert.equal(response.status, 400);
});

test('quietly accepts honeypot submissions without emailing', async () => {
  let sent = false;
  const handler = createContactHandler({ sendMail: async () => { sent = true; } });
  const response = await handler(makeRequest({ website: 'bot', name: '', email: '', topic: '', message: '' }));
  assert.equal(response.status, 200);
  assert.equal(sent, false);
});

test('sends validated requests and rate-limits repeated submissions', async () => {
  const mail = [];
  const handler = createContactHandler({ sendMail: async (message) => mail.push(message), now: () => 1000 });
  const payload = { name: 'Sam', email: 'sam@example.com', topic: 'Account', message: 'I need help signing in.' };
  const first = await handler(makeRequest(payload));
  const second = await handler(makeRequest(payload));
  assert.equal(first.status, 200);
  assert.equal(second.status, 429);
  assert.equal(mail.length, 1);
  assert.equal(mail[0].replyTo, payload.email);
});

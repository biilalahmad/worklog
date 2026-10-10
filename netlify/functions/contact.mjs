import nodemailer from 'nodemailer';

const supportAddress = process.env.SUPPORT_EMAIL || 'worklog.support@gmail.com';
const windowMs = 10 * 60 * 1000;
const submissions = new Map();

export function createContactHandler({ sendMail = defaultSendMail, now = Date.now } = {}) {
  return async (request) => {
    if (request.method !== 'POST') return reply(405, { message: 'Use POST to send a message.' }, { Allow: 'POST' });
    const length = Number(request.headers.get('content-length') || 0);
    if (length > 12000) return reply(413, { message: 'Message is too large. Please shorten it and try again.' });

    let body;
    try { body = await request.json(); }
    catch { return reply(400, { message: 'Please check the form and try again.' }); }
    if (!body || typeof body !== 'object' || Array.isArray(body)) return reply(400, { message: 'Please check the form and try again.' });
    if (typeof body.website === 'string' && body.website.trim()) return reply(200, { message: 'Thanks. Your message has been sent.' });

    const name = clean(body.name, 100);
    const email = clean(body.email, 254);
    const topic = clean(body.topic, 100);
    const message = clean(body.message, 5000);
    if (name.length < 1 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || topic.length < 1 || message.length < 10) {
      return reply(400, { message: 'Please provide a name, valid email, topic and message (at least 10 characters).' });
    }

    const forwarded = request.headers.get('x-nf-client-connection-ip') || request.headers.get('x-forwarded-for') || 'unknown';
    const ip = forwarded.split(',')[0].trim().slice(0, 80);
    const previous = submissions.get(ip);
    if (previous && now() - previous < windowMs) return reply(429, { message: 'Please wait a few minutes before sending another message.' });
    for (const [address, submittedAt] of submissions) {
      if (now() - submittedAt >= windowMs) submissions.delete(address);
    }

    try {
      await sendMail({
        from: process.env.GMAIL_SMTP_USER,
        to: supportAddress,
        replyTo: email,
        subject: `[WorkLog support] ${topic}`,
        text: `Name: ${name}\nEmail: ${email}\nTopic: ${topic}\n\n${message}`,
      });
      if (submissions.size >= 1000) submissions.delete(submissions.keys().next().value);
      submissions.set(ip, now());
      return reply(200, { message: 'Thanks. Your message has been sent.' });
    } catch (error) {
      console.error('WorkLog support email failed', error?.message || 'unknown error');
      return reply(503, { message: 'We couldn’t send your message right now. Please email support directly.' });
    }
  };
}

async function defaultSendMail(mail) {
  const user = process.env.GMAIL_SMTP_USER;
  const password = process.env.GMAIL_SMTP_APP_PASSWORD;
  if (!user || !password) throw new Error('SMTP settings are missing');
  const transport = nodemailer.createTransport({
    host: 'smtp.gmail.com', port: 465, secure: true,
    auth: { user, pass: password },
  });
  await transport.sendMail({ ...mail, from: `WorkLog Support <${user}>` });
}

function clean(value, max) {
  return typeof value === 'string' ? value.trim().replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, '').slice(0, max) : '';
}

function reply(status, body, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...extraHeaders },
  });
}

export default async (request) => createContactHandler()(request);

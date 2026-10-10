import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const tasks = new Set(["workout_plan", "nutrition_tips", "work_review", "finance_review", "reminder_ideas"]);
const maxRequestBytes = 2_048;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

function safeNumber(value: unknown): number | undefined {
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined;
  return Math.max(0, Math.min(value, 1_000_000));
}

function sanitizeContext(value: unknown): Record<string, Record<string, number | string>> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const whitelist: Record<string, string[]> = {
    gym: ["workoutsThisMonth", "workoutStreak", "mealsToday", "caloriesToday", "calorieTarget"],
    work: ["entriesThisMonth", "completedThisMonth", "hoursThisMonth", "videosThisMonth"],
    finance: ["incomeThisMonth", "expensesThisMonth"],
    reminders: ["upcomingCount"],
  };
  const clean: Record<string, Record<string, number | string>> = {};
  for (const [section, keys] of Object.entries(whitelist)) {
    const candidate = (value as Record<string, unknown>)[section];
    if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) continue;
    const metrics: Record<string, number> = {};
    for (const key of keys) {
      const number = safeNumber((candidate as Record<string, unknown>)[key]);
      if (number !== undefined) metrics[key] = number;
    }
    if (section === "finance") {
      const code = (candidate as Record<string, unknown>).currencyCode;
      if (typeof code === "string" && /^[A-Z]{3}$/.test(code)) metrics.currencyCode = code;
    }
    if (Object.keys(metrics).length) clean[section] = metrics;
  }
  return clean;
}

function validateReply(value: unknown, task: string): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const response = value as Record<string, unknown>;
  if (typeof response.summary !== "string" || !response.summary.trim() || response.summary.length > 3000 ||
      !Array.isArray(response.actions) || response.actions.length > 3) return null;
  const actions = [];
  const allowedDomains: Record<string, string[]> = {
    workout_plan: ["gym"],
    nutrition_tips: ["nutrition"],
    work_review: ["work", "reminders"],
    finance_review: ["reminders"],
    reminder_ideas: ["reminders"],
  };
  for (const item of response.actions) {
    if (!item || typeof item !== "object" || Array.isArray(item)) return null;
    const action = item as Record<string, unknown>;
    if (!new Set(["create", "update"]).has(String(action.operation)) ||
        !new Set(["gym", "nutrition", "work", "finance", "clients", "reminders"]).has(String(action.domain)) ||
        typeof action.title !== "string" || !action.title.trim() || action.title.length > 100 ||
        typeof action.details !== "string" || action.details.length > 700 ||
        (action.fields !== undefined && (!action.fields || typeof action.fields !== "object" || Array.isArray(action.fields)))) return null;
    // Suppress actions outside the selected specialist's narrow domain.
    // Finance tasks are insights-only; transaction and client writes are never AI-applied.
    if (!allowedDomains[task]?.includes(String(action.domain))) continue;
    actions.push({ operation: action.operation, domain: action.domain, title: action.title.trim(), details: action.details.trim(), fields: action.fields ?? {} });
  }
  return { summary: response.summary.trim(), actions };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (Number(req.headers.get("content-length") ?? 0) > maxRequestBytes) return json({ error: "invalid_request" }, 413);

  const authorization = req.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!url || !anonKey) return json({ error: "service_unavailable" }, 503);
  if (!authorization?.startsWith("Bearer ")) return json({ error: "authentication_required" }, 401);
  const auth = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false }, global: { headers: { Authorization: authorization } } });
  const { data: { user }, error } = await auth.auth.getUser();
  if (error || !user) return json({ error: "authentication_required" }, 401);
  if (!geminiKey) return json({ error: "assistant_not_configured" }, 503);

  let payload: Record<string, unknown>;
  try {
    const raw = await req.text();
    if (new TextEncoder().encode(raw).length > maxRequestBytes) return json({ error: "invalid_request" }, 413);
    payload = JSON.parse(raw);
  } catch (_) { return json({ error: "invalid_request" }, 400); }
  if (typeof payload.task !== "string" || !tasks.has(payload.task)) return json({ error: "invalid_request" }, 400);

  // The only model input is a fixed task plus numeric, allow-listed aggregates.
  // No free text, identifiers, names, contacts, notes, or raw records are sent.
  const context = sanitizeContext(payload.context);
  const instruction: Record<string, string> = {
    workout_plan: "Give a concise, safe general workout recommendation based only on the available gym metrics.",
    nutrition_tips: "Give general calorie tracking guidance; do not diagnose or prescribe medical diets.",
    work_review: "Give practical productivity insights from aggregate work metrics only.",
    finance_review: "Summarize aggregate totals and suggest budgeting habits only; no investment or legal advice.",
    reminder_ideas: "Suggest useful reminder ideas from the aggregate context; do not invent personal or client details.",
  };
  const prompt = `You are WorkLog's assistant. ${instruction[payload.task]}\nFinance totals, when present, are already in the currency's major units and the currencyCode identifies the unit. Never combine different currencies.\nUser metrics: ${JSON.stringify(context)}\nReturn an honest concise summary. Only suggest a create/update draft when the fixed task clearly supports it. Never suggest deletion, account, password, security, or financial transaction actions. Do not invent personal information.`;

  try {
    const upstream = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": geminiKey },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.35,
          maxOutputTokens: 600,
          thinkingConfig: { thinkingLevel: "low" },
          responseMimeType: "application/json",
          responseSchema: {
            type: "OBJECT",
            properties: {
              summary: { type: "STRING" },
              actions: { type: "ARRAY", maxItems: 3, items: { type: "OBJECT", properties: {
                operation: { type: "STRING", enum: ["create", "update"] },
                domain: { type: "STRING", enum: ["gym", "nutrition", "work", "finance", "clients", "reminders"] },
                title: { type: "STRING" }, details: { type: "STRING" }, fields: { type: "OBJECT" },
              }, required: ["operation", "domain", "title", "details", "fields"] } },
            }, required: ["summary", "actions"],
          },
        },
        safetySettings: [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
        ],
      }),
      signal: AbortSignal.timeout(35_000),
    });
    if (upstream.status === 429) return json({ error: "rate_limited" }, 429);
    if (!upstream.ok) return json({ error: "assistant_unavailable" }, 503);
    const body = await upstream.json();
    const text = body?.candidates?.[0]?.content?.parts?.find((part: { text?: string }) => typeof part.text === "string")?.text;
    if (typeof text !== "string") return json({ error: "invalid_assistant_response" }, 502);
    const reply = validateReply(JSON.parse(text), payload.task);
    return reply ? json(reply) : json({ error: "invalid_assistant_response" }, 502);
  } catch (_) { return json({ error: "assistant_unavailable" }, 503); }
});

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

type CachedRates = {
  id: number;
  rates: Record<string, number> | null;
  base_code: string;
  provider_updated_at: string | null;
  next_update_at: string | null;
  last_attempt_at: string;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function responseFor(cache: CachedRates, stale = false): Response {
  if (!cache.rates || !cache.provider_updated_at || !cache.next_update_at) {
    return json({ error: "rates_unavailable" }, 503);
  }
  return json({
    result: "success",
    base_code: cache.base_code,
    time_last_update_unix: Math.floor(Date.parse(cache.provider_updated_at) / 1000),
    time_next_update_unix: Math.floor(Date.parse(cache.next_update_at) / 1000),
    rates: cache.rates,
    stale,
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "GET" && req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authorization = req.headers.get("Authorization");
  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const exchangeRateKey = Deno.env.get("EXCHANGE_RATE_API_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    console.error("Exchange rates: required Supabase environment is missing");
    return json({ error: "service_unavailable" }, 503);
  }
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "authentication_required" }, 401);
  }

  const auth = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data: { user }, error: authError } = await auth.auth.getUser();
  if (authError || !user) return json({ error: "authentication_required" }, 401);

  const admin = createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: initial, error: readError } = await admin
    .from("exchange_rate_cache")
    .select("id, rates, base_code, provider_updated_at, next_update_at, last_attempt_at")
    .eq("id", 1)
    .maybeSingle();
  if (readError || !initial) {
    console.error("Exchange rates: unable to read shared cache", readError?.message);
    return json({ error: "rates_cache_unavailable" }, 503);
  }

  let cache = initial as CachedRates;
  const now = new Date();
  const hasRates = !!cache.rates && !!cache.provider_updated_at && !!cache.next_update_at;
  const providerStillFresh = hasRates && Date.parse(cache.next_update_at!) > now.getTime();
  if (providerStillFresh) return responseFor(cache);

  // All users share this row. The conditional UPDATE is an atomic refresh
  // claim. Successful refreshes are cached until the provider's next update;
  // a short retry window lets transient/provider errors recover without
  // allowing every request to consume the provider quota.
  const retryAfter = new Date(now.getTime() - 5 * 60 * 1000).toISOString();
  const { data: claimed, error: claimError } = await admin
    .from("exchange_rate_cache")
    .update({ last_attempt_at: now.toISOString(), updated_at: now.toISOString() })
    .eq("id", 1)
    .lt("last_attempt_at", retryAfter)
    .select("id");

  if (claimError) {
    console.error("Exchange rates: unable to claim daily refresh", claimError.message);
    return hasRates ? responseFor(cache, true) : json({ error: "rates_cache_unavailable" }, 503);
  }

  if (!claimed || claimed.length === 0) {
    // Another caller owns the refresh or attempted one within the retry
    // window. Re-read so this caller can return the latest snapshot.
    const { data: latest, error: latestError } = await admin
      .from("exchange_rate_cache")
      .select("id, rates, base_code, provider_updated_at, next_update_at, last_attempt_at")
      .eq("id", 1)
      .maybeSingle();
    if (!latestError && latest) cache = latest as CachedRates;
    return responseFor(cache, true);
  }

  if (!exchangeRateKey) {
    console.error("Exchange rates: EXCHANGE_RATE_API_KEY secret is missing");
    return hasRates ? responseFor(cache, true) : json({ error: "rates_not_configured" }, 503);
  }

  try {
    const upstream = await fetch("https://v6.exchangerate-api.com/v6/latest/USD", {
      method: "GET",
      headers: { Authorization: `Bearer ${exchangeRateKey}` },
      signal: AbortSignal.timeout(8000),
    });
    if (!upstream.ok) {
      console.error(`Exchange rates provider returned HTTP ${upstream.status}`);
      return hasRates ? responseFor(cache, true) : json({ error: "rates_provider_unavailable" }, 503);
    }

    const payload = await upstream.json();
    // ExchangeRate-API calls this field `conversion_rates` (not `rates`).
    // We normalize it to our internal/cache `rates` shape below.
    const providerRates = payload?.conversion_rates;
    if (payload?.result !== "success" || payload?.base_code !== "USD" ||
        typeof providerRates !== "object" || providerRates === null || Array.isArray(providerRates)) {
      console.error("Exchange rates provider returned an invalid payload", {
        result: payload?.result ?? "missing",
        errorType: payload?.["error-type"] ?? "not_provided",
        baseCode: payload?.base_code ?? "missing",
        hasConversionRates: providerRates != null,
      });
      return hasRates ? responseFor(cache, true) : json({ error: "rates_provider_unavailable" }, 503);
    }

    const rates: Record<string, number> = { USD: 1 };
    for (const [code, value] of Object.entries(providerRates as Record<string, unknown>)) {
      if (/^[A-Z]{3}$/.test(code) && typeof value === "number" &&
          Number.isFinite(value) && value > 0) {
        rates[code] = value;
      }
    }
    if (Object.keys(rates).length < 2) {
      console.error("Exchange rates provider returned no usable rates");
      return hasRates ? responseFor(cache, true) : json({ error: "rates_provider_unavailable" }, 503);
    }

    const lastUpdate = Number(payload.time_last_update_unix);
    const nextUpdate = Number(payload.time_next_update_unix);
    if (!Number.isFinite(lastUpdate) || !Number.isFinite(nextUpdate) || nextUpdate <= lastUpdate) {
      console.error("Exchange rates provider returned invalid update timestamps");
      return hasRates ? responseFor(cache, true) : json({ error: "rates_provider_unavailable" }, 503);
    }

    const refreshedAt = new Date();
    const { data: saved, error: saveError } = await admin
      .from("exchange_rate_cache")
      .update({
        rates,
        base_code: "USD",
        provider_updated_at: new Date(lastUpdate * 1000).toISOString(),
        next_update_at: new Date(nextUpdate * 1000).toISOString(),
        updated_at: refreshedAt.toISOString(),
      })
      .eq("id", 1)
      .select("id, rates, base_code, provider_updated_at, next_update_at, last_attempt_at")
      .single();

    if (saveError || !saved) {
      console.error("Exchange rates: unable to persist refreshed cache", saveError?.message);
      return hasRates ? responseFor(cache, true) : json({ error: "rates_cache_unavailable" }, 503);
    }
    return responseFor(saved as CachedRates);
  } catch (error) {
    console.error("Exchange rates provider request failed", error instanceof Error ? error.message : "unknown error");
    return hasRates ? responseFor(cache, true) : json({ error: "rates_provider_unavailable" }, 503);
  }
});

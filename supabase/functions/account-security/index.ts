import {
  createClient,
  type User,
} from "https://esm.sh/@supabase/supabase-js@2.49.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Action = "reset_password" | "change_password" | "delete_account";
type Operation = "request_code" | "verify_code" | "complete_action";

const actions = new Set<Action>([
  "reset_password",
  "change_password",
  "delete_account",
]);

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function sha256(value: string): Promise<string> {
  return crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)).then((
    digest,
  ) =>
    [...new Uint8Array(digest)].map((byte) =>
      byte.toString(16).padStart(2, "0")
    ).join("")
  );
}

function ticketValue(): string {
  return `${crypto.randomUUID()}${crypto.randomUUID()}`;
}

function isAction(value: unknown): value is Action {
  return typeof value === "string" && actions.has(value as Action);
}

function normalizedEmail(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  return email.length <= 320 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
    ? email
    : null;
}

async function callerUser(
  req: Request,
  url: string,
  anonKey: string,
): Promise<User | null> {
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return null;
  const client = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: authorization } },
  });
  const { data, error } = await client.auth.getUser();
  return error ? null : data.user;
}

function requireCode(value: unknown): string | null {
  return typeof value === "string" && /^\d{6,10}$/.test(value) ? value : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return response({ error: "method_not_allowed" }, 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return response({ error: "security_service_unavailable" }, 500);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch (_) {
    return response({ error: "invalid_request" }, 400);
  }

  const operation = payload.operation as Operation;
  const action = payload.action;
  if (
    !isAction(action) ||
    !["request_code", "verify_code", "complete_action"].includes(operation)
  ) {
    return response({ error: "invalid_request" }, 400);
  }

  const service = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const auth = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const passwordVerifier = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    if (operation === "request_code") {
      let email = normalizedEmail(payload.email);
      let user: User | null = null;
      if (action !== "reset_password") {
        user = await callerUser(req, url, anonKey);
        if (!user?.email) {
          return response({ error: "authentication_required" }, 401);
        }
        email = normalizedEmail(user.email);
      }
      if (!email) return response({ error: "invalid_request" }, 400);

      // Enforce a per-account rolling 24-hour code-request limit before
      // replacing the existing challenge or asking Auth to send an email.
      const { data: requestAllowed, error: requestLimitError } =
        await service.rpc("reserve_auth_action_code_request", {
          p_action: action,
          p_email: email,
          p_user_id: user?.id ?? null,
        });
      if (requestLimitError) {
        return response({ error: "security_service_unavailable" }, 500);
      }
      if (requestAllowed !== true) {
        const limitCode = {
          reset_password: "password_reset_request_limit",
          change_password: "password_change_request_limit",
          delete_account: "delete_account_request_limit",
        }[action];
        return response({ error: limitCode }, 429);
      }

      // Capture the start time before Auth issues the OTP; the database uses
      // this deadline as a strict server-side 180-second upper bound.
      const requestedAt = new Date().toISOString();
      const { error: prepareError } = await service.rpc(
        "prepare_auth_action_challenge",
        {
          p_email: email,
          p_action: action,
          p_requested_at: requestedAt,
        },
      );
      if (prepareError) {
        return response({ error: "security_service_unavailable" }, 500);
      }

      const { error: sendError } = await auth.auth.resetPasswordForEmail(email);
      if (sendError) {
        // Invalidate the challenge even when the mail provider rejects the
        // resend, so an older code/ticket cannot stay usable after a request.
        await service.rpc("prepare_auth_action_challenge", {
          p_email: email,
          p_action: action,
          p_requested_at: new Date(Date.now() - 181_000).toISOString(),
        });
        const authError = sendError as typeof sendError & {
          status?: number;
          code?: string;
        };
        const isRateLimited = authError.status === 429 ||
          authError.code?.toLowerCase().includes("rate_limit") === true ||
          authError.code?.toLowerCase().includes("too_many") === true;
        return isRateLimited
          ? response({ error: "rate_limited" }, 429)
          : response({ error: "code_request_failed" }, 502);
      }

      // Keep reset responses indistinguishable for registered and unknown emails.
      return response({
        success: true,
        message: "If the account exists, a code was sent.",
      });
    }

    if (operation === "verify_code") {
      const token = requireCode(payload.code);
      if (!token) return response({ error: "invalid_or_expired_code" }, 400);

      let email = normalizedEmail(payload.email);
      let caller: User | null = null;
      if (action !== "reset_password") {
        caller = await callerUser(req, url, anonKey);
        if (!caller?.email) {
          return response({ error: "authentication_required" }, 401);
        }
        email = normalizedEmail(caller.email);
      }
      if (!email) return response({ error: "invalid_or_expired_code" }, 400);

      const { data, error } = await auth.auth.verifyOtp({
        email,
        token,
        type: "recovery",
      });
      if (error || !data.user?.id || !data.user.email) {
        return response({ error: "invalid_or_expired_code" }, 400);
      }
      if (
        data.user.email.toLowerCase() !== email ||
        (caller && caller.id !== data.user.id)
      ) {
        return response({ error: "invalid_or_expired_code" }, 400);
      }

      const ticket = ticketValue();
      const { data: issued, error: issueError } = await service.rpc(
        "issue_auth_action_ticket",
        {
          p_email: email,
          p_action: action,
          p_user_id: data.user.id,
          p_ticket_hash: await sha256(ticket),
        },
      );
      if (issueError || issued !== true) {
        return response({ error: "invalid_or_expired_code" }, 400);
      }
      return response({ success: true, email, ticket });
    }

    const ticket =
      typeof payload.ticket === "string" && payload.ticket.length === 72
        ? payload.ticket
        : null;
    const email = normalizedEmail(payload.email);
    if (!ticket || !email) {
      return response({ error: "invalid_or_expired_code" }, 400);
    }

    let caller: User | null = null;
    if (action !== "reset_password") {
      caller = await callerUser(req, url, anonKey);
      if (!caller?.email || caller.email.toLowerCase() !== email) {
        return response({ error: "authentication_required" }, 401);
      }
    }

    const password = typeof payload.newPassword === "string"
      ? payload.newPassword
      : "";
    if (action !== "delete_account") {
      if (
        password.length < 8 || password.length > 128 ||
        !/[A-Za-z]/.test(password) || !/[0-9]/.test(password)
      ) {
        return response({ error: "password_policy" }, 400);
      }
    }

    let currentPassword: string | null = null;
    if (action === "change_password") {
      currentPassword = typeof payload.currentPassword === "string"
        ? payload.currentPassword
        : null;
      if (!currentPassword || !caller?.email || !caller.id) {
        return response({ error: "invalid_current_password" }, 400);
      }

      const { data: verifiedCurrent, error: currentPasswordError } =
        await passwordVerifier.auth.signInWithPassword({
          email: caller.email,
          password: currentPassword,
        });
      if (currentPasswordError) {
        if (
          currentPasswordError.status === 429 ||
          (currentPasswordError.status ?? 0) >= 500
        ) {
          return response({ error: "password_verification_unavailable" }, 503);
        }
        return response({ error: "invalid_current_password" }, 400);
      }
      if (verifiedCurrent.user?.id !== caller.id) {
        return response({ error: "invalid_current_password" }, 400);
      }
      if (currentPassword === password) {
        return response({ error: "password_reuse" }, 400);
      }
    }

    let userId: string | null = null;
    let reservationId: string | null = null;
    if (action === "change_password" && caller) {
      const { data, error } = await service.rpc(
        "consume_and_reserve_password_change",
        {
          p_user_id: caller.id,
          p_email: email,
          p_ticket_hash: await sha256(ticket),
        },
      );
      if (error) {
        return response({ error: "security_service_unavailable" }, 500);
      }
      const result = Array.isArray(data) ? data[0] : data;
      if (result?.limit_reached === true) {
        return response({ error: "password_change_limit" }, 429);
      }
      userId = typeof result?.consumed_user_id === "string"
        ? result.consumed_user_id
        : null;
      reservationId = typeof result?.reservation_id === "string"
        ? result.reservation_id
        : null;
      if (!userId || !reservationId) {
        return response({ error: "invalid_or_expired_code" }, 400);
      }
    } else {
      const { data, error } = await service.rpc("consume_auth_action_ticket", {
        p_email: email,
        p_action: action,
        p_ticket_hash: await sha256(ticket),
        p_expected_user_id: caller?.id ?? null,
      });
      if (error || typeof data !== "string") {
        return response({ error: "invalid_or_expired_code" }, 400);
      }
      userId = data;
    }
    if (caller && userId !== caller.id) {
      return response({ error: "authentication_required" }, 401);
    }

    if (action === "delete_account") {
      const { error } = await service.auth.admin.deleteUser(userId);
      if (error) return response({ error: "account_action_failed" }, 400);
      return response({ success: true });
    }

    const { error } = await service.auth.admin.updateUserById(userId, {
      password,
    });
    if (error) {
      if (reservationId && caller) {
        await service.rpc("cancel_password_change_reservation", {
          p_user_id: caller.id,
          p_reservation_id: reservationId,
        });
      }
      return response({ error: "account_action_failed" }, 400);
    }
    if (reservationId && caller) {
      // Even if this bookkeeping update fails, the reservation itself remains
      // counted, so it cannot open an extra change slot.
      await service.rpc("complete_password_change_reservation", {
        p_user_id: caller.id,
        p_reservation_id: reservationId,
      });
    }
    return response({ success: true });
  } catch (_) {
    return response({ error: "security_service_unavailable" }, 500);
  }
});

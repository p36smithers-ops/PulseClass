import { createClient } from "npm:@supabase/supabase-js@2.119.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const secretMap = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
const publishableMap = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
const secretKey = secretMap.default as string | undefined;
const allowedPublishableKeys = new Set(Object.values(publishableMap).filter((v): v is string => typeof v === "string"));

if (!supabaseUrl || !secretKey || allowedPublishableKeys.size === 0) {
  throw new Error("PulseClass server configuration is incomplete.");
}

const admin = createClient(supabaseUrl, secretKey, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});

const json = (status: number, payload: Record<string, unknown>) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const isToken = (value: unknown): value is string =>
  typeof value === "string" && /^[a-f0-9]{64}$/.test(value);

const hex = (bytes: Uint8Array) =>
  Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return hex(new Uint8Array(digest));
}

async function hmac(value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secretKey!),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return hex(new Uint8Array(signature));
}

function clientIp(req: Request): string | null {
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf;
  const forwarded = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return forwarded || null;
}

async function findActiveParticipant(token: string) {
  const tokenHash = await sha256(token);
  const { data: participant, error } = await admin
    .from("lesson_participants")
    .select("id, session_id, class_id, display_name, expires_at, revoked_at, last_reading_at")
    .eq("token_hash", tokenHash)
    .maybeSingle();

  if (error) throw error;
  if (!participant || participant.revoked_at || Date.parse(participant.expires_at) <= Date.now()) {
    return { participant: null, session: null };
  }

  const { data: session, error: sessionError } = await admin
    .from("sessions")
    .select("id, class_id, lesson_title, target_zone, planned_duration_minutes, started_at, ended_at")
    .eq("id", participant.session_id)
    .eq("class_id", participant.class_id)
    .is("ended_at", null)
    .maybeSingle();

  if (sessionError) throw sessionError;
  if (!session) {
    await admin.from("lesson_participants")
      .update({ revoked_at: new Date().toISOString() })
      .eq("id", participant.id);
    return { participant: null, session: null };
  }
  return { participant, session };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "Method not allowed." });

  const callerKey = req.headers.get("apikey") ?? "";
  if (!allowedPublishableKeys.has(callerKey)) return json(401, { error: "Invalid client key." });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "A JSON request body is required." });
  }

  const action = body.action;

  try {
    if (action === "join") {
      const displayName = typeof body.display_name === "string" ? body.display_name.trim() : "";
      const joinCode = typeof body.join_code === "string" ? body.join_code.trim().toUpperCase() : "";
      const token = body.token;

      if (displayName.length < 1 || displayName.length > 60) {
        return json(400, { error: "Enter a name between 1 and 60 characters." });
      }
      if (!/^[A-F0-9]{8,16}$/.test(joinCode)) {
        return json(400, { error: "Check the class code and try again." });
      }
      if (!isToken(token)) return json(400, { error: "The device token is invalid." });

      const ip = clientIp(req);
      if (!ip) return json(429, { error: "Could not verify the request source. Try again on the school network." });
      const ipHash = await hmac(ip);
      const { data: allowed, error: limitError } = await admin.rpc("consume_join_attempt", {
        p_ip_hash: ipHash,
      });
      if (limitError) throw limitError;
      if (!allowed) return json(429, { error: "Too many join attempts. Wait 15 minutes and try again." });

      const { data: classRow, error: classError } = await admin
        .from("classes")
        .select("id, name")
        .eq("join_code", joinCode)
        .maybeSingle();
      if (classError) throw classError;
      if (!classRow) return json(400, { error: "Invalid class code." });

      const { data: session, error: sessionError } = await admin
        .from("sessions")
        .select("id, class_id, lesson_title, target_zone, planned_duration_minutes, started_at, ended_at")
        .eq("class_id", classRow.id)
        .is("ended_at", null)
        .maybeSingle();
      if (sessionError) throw sessionError;
      if (!session) return json(409, { error: "Your teacher has not opened a lesson yet." });

      const tokenHash = await sha256(token);
      const { data: existing, error: existingError } = await admin
        .from("lesson_participants")
        .select("id, session_id, class_id, expires_at, revoked_at")
        .eq("token_hash", tokenHash)
        .maybeSingle();
      if (existingError) throw existingError;

      if (existing) {
        if (
          existing.session_id !== session.id ||
          existing.revoked_at ||
          Date.parse(existing.expires_at) <= Date.now()
        ) {
          return json(409, { error: "This device token belongs to an earlier lesson. A new token is required." });
        }
        const { error: updateError } = await admin
          .from("lesson_participants")
          .update({ display_name: displayName, last_seen_at: new Date().toISOString() })
          .eq("id", existing.id);
        if (updateError) throw updateError;
        return json(200, {
          token,
          participant_id: existing.id,
          display_name: displayName,
          class_id: classRow.id,
          class_name: classRow.name,
          session,
        });
      }

      const expiresAt = new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString();
      const { data: participant, error: insertError } = await admin
        .from("lesson_participants")
        .insert({
          session_id: session.id,
          class_id: classRow.id,
          display_name: displayName,
          token_hash: tokenHash,
          expires_at: expiresAt,
        })
        .select("id")
        .single();
      if (insertError) throw insertError;

      return json(200, {
        token,
        participant_id: participant.id,
        display_name: displayName,
        class_id: classRow.id,
        class_name: classRow.name,
        session,
      });
    }

    if (action === "status") {
      const token = body.token;
      if (!isToken(token)) return json(400, { error: "The device token is invalid." });
      const { participant, session } = await findActiveParticipant(token);
      if (!participant || !session) {
        return json(410, { error: "This lesson connection has ended. Join again when your teacher opens a new lesson." });
      }
      const now = new Date().toISOString();
      const [{ data: classRow, error: classError }, { error: updateError }] = await Promise.all([
        admin.from("classes").select("name").eq("id", participant.class_id).single(),
        admin.from("lesson_participants").update({ last_seen_at: now }).eq("id", participant.id),
      ]);
      if (classError) throw classError;
      if (updateError) throw updateError;
      return json(200, {
        participant_id: participant.id,
        display_name: participant.display_name,
        class_id: participant.class_id,
        class_name: classRow.name,
        session,
      });
    }

    if (action === "reading") {
      const token = body.token;
      const bpm = body.bpm;
      const deviceName = typeof body.device_name === "string" ? body.device_name.slice(0, 80) : "Bluetooth HR monitor";
      if (!isToken(token)) return json(400, { error: "The device token is invalid." });
      if (!Number.isInteger(bpm) || (bpm as number) < 25 || (bpm as number) > 250) {
        return json(400, { error: "Heart rate must be between 25 and 250 BPM." });
      }

      const { participant, session } = await findActiveParticipant(token);
      if (!participant || !session) {
        return json(410, { error: "This lesson has ended. Join again for your next lesson." });
      }

      const { error: recordError } = await admin.rpc("record_lesson_reading", {
        p_participant_id: participant.id,
        p_bpm: bpm as number,
        p_device_name: deviceName || "Bluetooth HR monitor",
      });
      if (recordError) {
        if (recordError.message.toLowerCase().includes("rate limit")) {
          return json(429, { error: "Reading rate is too high." });
        }
        if (recordError.message.toLowerCase().includes("ended") ||
            recordError.message.toLowerCase().includes("expired") ||
            recordError.message.toLowerCase().includes("revoked")) {
          return json(410, { error: "This lesson has ended. Join again for your next lesson." });
        }
        throw recordError;
      }
      return json(200, { accepted: true });
    }

    return json(400, { error: "Unknown action." });
  } catch (error) {
    console.error("student-access request failed", error instanceof Error ? error.message : "unknown error");
    return json(500, { error: "PulseClass could not complete that request. Try again." });
  }
});

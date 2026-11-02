// deno-lint-ignore-file no-explicit-any
import { JWT } from "npm:google-auth-library@9.15.1";

export type FcmPayload = {
  title: string;
  body: string;
  tag?: string;
  route?: string;
  /** Android notification channel id (default ice_pos_alerts). */
  channelId?: string;
  /** Extra data fields merged into FCM data payload. */
  data?: Record<string, string>;
  /** When true, only tokens with role=admin (or profiles.role=admin). */
  adminsOnly?: boolean;
};

let _accessToken: { token: string; exp: number } | null = null;

async function getAccessToken(): Promise<string | null> {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
  const privateKey = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(/\\n/g, "\n");
  if (!projectId || !clientEmail || !privateKey) return null;

  const now = Math.floor(Date.now() / 1000);
  if (_accessToken && _accessToken.exp > now + 60) {
    return _accessToken.token;
  }

  const client = new JWT({
    email: clientEmail,
    key: privateKey,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const creds = await client.authorize();
  const token = creds.access_token;
  if (!token) return null;
  _accessToken = { token, exp: now + 3500 };
  return token;
}

async function resolveAdminUserIds(supabase: any): Promise<Set<string>> {
  const ids = new Set<string>();
  const { data, error } = await supabase.from("profiles").select("id, role").eq("role", "admin");
  if (error) {
    console.error("fcm resolveAdminUserIds:", error);
    return ids;
  }
  for (const row of (data ?? []) as Array<{ id: string; role: string }>) {
    if (row.id) ids.add(row.id);
  }
  return ids;
}

export async function sendFcmToStore(
  supabase: any,
  storeId: number,
  payload: FcmPayload,
): Promise<number> {
  const accessToken = await getAccessToken();
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
  if (!accessToken || !projectId) return 0;

  let query = supabase
    .from("fcm_device_tokens")
    .select("token, role, user_id")
    .eq("store_id", storeId)
    .eq("is_active", true);
  if (payload.adminsOnly) {
    query = query.eq("role", "admin");
  }
  const { data: rows, error } = await query;
  if (error) throw error;

  let tokenRows = (rows ?? []) as Array<{ token: string; role?: string; user_id?: string }>;
  if (payload.adminsOnly && tokenRows.length === 0) {
    // Fallback: tokens without role column filled — match profiles.admin by user_id.
    const { data: allRows, error: allErr } = await supabase
      .from("fcm_device_tokens")
      .select("token, role, user_id")
      .eq("store_id", storeId)
      .eq("is_active", true);
    if (allErr) throw allErr;
    const adminIds = await resolveAdminUserIds(supabase);
    tokenRows = ((allRows ?? []) as Array<{ token: string; role?: string; user_id?: string }>).filter(
      (r) => r.role === "admin" || (r.user_id && adminIds.has(r.user_id)),
    );
  }

  const tokens = tokenRows.map((r) => r.token).filter(Boolean);
  if (!tokens.length) return 0;

  const channelId = payload.channelId ?? "ice_pos_alerts";
  const dataPayload: Record<string, string> = {
    tag: payload.tag ?? "",
    route: payload.route ?? "",
    ...(payload.data ?? {}),
  };

  let sent = 0;
  for (const token of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: payload.title, body: payload.body },
            data: dataPayload,
            android: {
              priority: "HIGH",
              notification: {
                channel_id: channelId,
                notification_priority: "PRIORITY_MAX",
                default_vibrate_timings: true,
              },
            },
          },
        }),
      },
    );
    if (res.ok) {
      sent++;
      continue;
    }
    const errText = await res.text();
    if (
      errText.includes("UNREGISTERED") ||
      errText.includes("INVALID_ARGUMENT") ||
      errText.includes("NOT_FOUND")
    ) {
      await supabase
        .from("fcm_device_tokens")
        .update({ is_active: false, updated_at: new Date().toISOString() })
        .eq("token", token);
    }
  }
  return sent;
}

/** Broadcast temp alerts to all active admin tokens (any store). */
export async function sendFcmToAdmins(
  supabase: any,
  payload: FcmPayload,
): Promise<number> {
  const accessToken = await getAccessToken();
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
  if (!accessToken || !projectId) return 0;

  const { data: stores, error: storesErr } = await supabase
    .from("fcm_device_tokens")
    .select("store_id")
    .eq("is_active", true);
  if (storesErr) throw storesErr;
  const storeIds = [
    ...new Set(
      ((stores ?? []) as Array<{ store_id: number }>).map((r) => Number(r.store_id)).filter((n) =>
        Number.isFinite(n) && n > 0
      ),
    ),
  ];
  let sent = 0;
  for (const storeId of storeIds) {
    sent += await sendFcmToStore(supabase, storeId, { ...payload, adminsOnly: true });
  }
  return sent;
}

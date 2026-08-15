// deno-lint-ignore-file no-explicit-any
import { JWT } from "npm:google-auth-library@9.15.1";

export type FcmPayload = {
  title: string;
  body: string;
  tag?: string;
  route?: string;
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

export async function sendFcmToStore(
  supabase: any,
  storeId: number,
  payload: FcmPayload,
): Promise<number> {
  const accessToken = await getAccessToken();
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
  if (!accessToken || !projectId) return 0;

  const { data: rows, error } = await supabase
    .from("fcm_device_tokens")
    .select("token")
    .eq("store_id", storeId)
    .eq("is_active", true);
  if (error) throw error;
  const tokens = ((rows ?? []) as Array<{ token: string }>).map((r) => r.token).filter(Boolean);
  if (!tokens.length) return 0;

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
            data: {
              tag: payload.tag ?? "",
              route: payload.route ?? "",
            },
            android: { priority: "HIGH", notification: { channel_id: "ice_pos_alerts" } },
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

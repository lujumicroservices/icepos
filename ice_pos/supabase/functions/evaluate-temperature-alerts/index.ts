// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import webpush from "npm:web-push@3.6.7";
import { sendFcmToAdmins } from "../_shared/fcm.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const vapidPublicKey = Deno.env.get("WEB_PUSH_VAPID_PUBLIC_KEY") ?? "";
const vapidPrivateKey = Deno.env.get("WEB_PUSH_VAPID_PRIVATE_KEY") ?? "";
const vapidSubject = Deno.env.get("WEB_PUSH_VAPID_SUBJECT") ?? "mailto:admin@example.com";

if (vapidPublicKey && vapidPrivateKey) {
  webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

function freezerKeyForSensor(sensorId: string): string {
  const lower = sensorId.trim().toLowerCase();
  if (lower.endsWith("79d") || lower.endsWith("0a6")) return "freezer1";
  return "freezer2";
}

type Setting = {
  freezer_key: string;
  min_c: number;
  max_c: number;
  stale_minutes: number;
  enabled: boolean;
  notify_cooldown_minutes: number;
};

type Reading = {
  sensor_id: string;
  temperature_c: number;
  read_at: string;
};

async function sendWebPushToAdmins(payload: {
  title: string;
  body: string;
  tag: string;
}): Promise<number> {
  if (!vapidPublicKey || !vapidPrivateKey) return 0;

  const { data: admins, error: adminErr } = await supabase
    .from("profiles")
    .select("id")
    .eq("role", "admin");
  if (adminErr) throw adminErr;
  const adminIds = new Set(
    ((admins ?? []) as Array<{ id: string }>).map((a) => a.id).filter(Boolean),
  );

  const { data: subs, error: subsErr } = await supabase
    .from("web_push_subscriptions")
    .select("endpoint,p256dh,auth,user_id")
    .eq("is_active", true);
  if (subsErr) throw subsErr;

  const list = ((subs ?? []) as Array<{
    endpoint: string;
    p256dh: string;
    auth: string;
    user_id: string | null;
  }>).filter((s) => s.user_id && adminIds.has(s.user_id));

  let sent = 0;
  for (const s of list) {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        JSON.stringify({
          title: payload.title,
          body: payload.body,
          tag: payload.tag,
          route: "temperature_history",
          type: "temp_alert",
          url: "/",
        }),
      );
      sent++;
    } catch (e: any) {
      const code = Number(e?.statusCode ?? 0);
      if (code === 404 || code === 410) {
        await supabase
          .from("web_push_subscriptions")
          .update({ is_active: false, updated_at: new Date().toISOString() })
          .eq("endpoint", s.endpoint);
      }
    }
  }
  return sent;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY." }),
      { status: 500 },
    );
  }

  try {
    const { data: settingsRows, error: settingsErr } = await supabase
      .from("temperature_alert_settings")
      .select("*")
      .eq("enabled", true);
    if (settingsErr) throw settingsErr;
    const settings = (settingsRows ?? []) as Setting[];
    if (!settings.length) {
      return new Response(JSON.stringify({ ok: true, alerts: 0, reason: "no_enabled_settings" }));
    }
    const byKey = new Map(settings.map((s) => [s.freezer_key, s]));

    const { data: readingRows, error: readErr } = await supabase
      .from("sensor_readings")
      .select("sensor_id,temperature_c,read_at")
      .order("read_at", { ascending: false })
      .limit(500);
    if (readErr) throw readErr;

    const latest = new Map<string, Reading>();
    for (const raw of (readingRows ?? []) as Reading[]) {
      const sid = String(raw.sensor_id ?? "").trim();
      if (!sid || latest.has(sid)) continue;
      latest.set(sid, raw);
    }

    const now = Date.now();
    const fired: Array<{ sensor_id: string; kind: string }> = [];
    let fcmSent = 0;
    let webSent = 0;

    for (const [sensorId, reading] of latest) {
      const key = freezerKeyForSensor(sensorId);
      const s = byKey.get(key);
      if (!s) continue;

      const readAtMs = Date.parse(reading.read_at);
      const ageMin = Number.isFinite(readAtMs) ? (now - readAtMs) / 60000 : Infinity;
      let kind: string | null = null;
      let body = "";

      if (ageMin >= s.stale_minutes) {
        kind = "stale";
        body = `${sensorId}: sin lectura hace ${Math.floor(ageMin)} min (límite ${s.stale_minutes}).`;
      } else if (reading.temperature_c < s.min_c) {
        kind = "below_min";
        body = `${sensorId}: ${reading.temperature_c.toFixed(1)} °C bajo mínimo ${s.min_c} °C.`;
      } else if (reading.temperature_c > s.max_c) {
        kind = "above_max";
        body = `${sensorId}: ${reading.temperature_c.toFixed(1)} °C sobre máximo ${s.max_c} °C.`;
      }

      if (!kind) {
        await supabase
          .from("temperature_alert_events")
          .delete()
          .eq("sensor_id", sensorId)
          .in("kind", ["stale", "below_min", "above_max"]);
        continue;
      }

      const { data: prev } = await supabase
        .from("temperature_alert_events")
        .select("last_notified_at")
        .eq("sensor_id", sensorId)
        .eq("kind", kind)
        .maybeSingle();

      const lastAt = prev?.last_notified_at ? Date.parse(String(prev.last_notified_at)) : 0;
      const cooldownMs = s.notify_cooldown_minutes * 60_000;
      if (Number.isFinite(lastAt) && now - lastAt < cooldownMs) {
        continue;
      }

      const title = kind === "stale" ? "Sensor sin datos" : "Alerta de temperatura";
      const tag = `temp-alert-${sensorId}-${kind}`;

      fcmSent += await sendFcmToAdmins(supabase, {
        title,
        body,
        tag,
        route: "temperature_history",
        channelId: "ice_pos_temp_alarm",
        adminsOnly: true,
        data: {
          type: "temp_alert",
          kind,
          sensor_id: sensorId,
          freezer_key: key,
        },
      });

      webSent += await sendWebPushToAdmins({ title, body, tag });

      await supabase.from("temperature_alert_events").upsert(
        {
          sensor_id: sensorId,
          kind,
          last_notified_at: new Date().toISOString(),
          last_value_c: reading.temperature_c,
        },
        { onConflict: "sensor_id,kind" },
      );
      fired.push({ sensor_id: sensorId, kind });
    }

    return new Response(
      JSON.stringify({
        ok: true,
        alerts: fired.length,
        fcm_sent: fcmSent,
        web_sent: webSent,
        fired,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

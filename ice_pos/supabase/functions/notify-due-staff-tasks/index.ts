// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import webpush from "npm:web-push@3.6.7";
import { sendFcmToStore } from "../_shared/fcm.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const vapidPublicKey = Deno.env.get("WEB_PUSH_VAPID_PUBLIC_KEY") ?? "";
const vapidPrivateKey = Deno.env.get("WEB_PUSH_VAPID_PRIVATE_KEY") ?? "";
const vapidSubject = Deno.env.get("WEB_PUSH_VAPID_SUBJECT") ?? "mailto:admin@example.com";

if (vapidPublicKey && vapidPrivateKey) {
  webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function sendWebToStore(
  storeId: number,
  payload: { title: string; body: string; tag: string },
): Promise<number> {
  if (!vapidPublicKey || !vapidPrivateKey) return 0;
  const { data: subs, error: subsErr } = await supabase
    .from("web_push_subscriptions")
    .select("endpoint,p256dh,auth")
    .eq("store_id", storeId)
    .eq("is_active", true);
  if (subsErr) throw subsErr;
  const list = (subs ?? []) as Array<{ endpoint: string; p256dh: string; auth: string }>;
  let sent = 0;
  for (const s of list) {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        JSON.stringify({ ...payload, url: "/" }),
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
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY." }),
      { status: 500 },
    );
  }

  try {
    const now = new Date().toISOString();
    const { data: tasks, error: tasksErr } = await supabase
      .from("staff_tasks")
      .select("id, store_id, title, notify_at")
      .is("cancelled_at", null)
      .is("notification_sent_at", null)
      .lte("notify_at", now)
      .order("notify_at", { ascending: true })
      .limit(50);
    if (tasksErr) throw tasksErr;

    const rows = (tasks ?? []) as Array<{ id: number; store_id: number; title: string }>;

    let tasksNotified = 0;
    let webSent = 0;
    let fcmSent = 0;
    for (const t of rows) {
      const bodyText = t.title.length > 120 ? `${t.title.slice(0, 117)}...` : t.title;
      const payload = {
        title: "Tarea pendiente",
        body: bodyText,
        tag: `staff-task-${t.id}`,
        route: "staff_tasks",
      };
      webSent += await sendWebToStore(t.store_id, payload);
      fcmSent += await sendFcmToStore(supabase, t.store_id, payload);
      await supabase
        .from("staff_tasks")
        .update({ notification_sent_at: new Date().toISOString() })
        .eq("id", t.id);
      tasksNotified++;
    }

    return new Response(
      JSON.stringify({
        ok: true,
        tasks_notified: tasksNotified,
        web_sent: webSent,
        fcm_sent: fcmSent,
      }),
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

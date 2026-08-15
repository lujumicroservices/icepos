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
    const body = await req.json();
    const storeId = Number(body?.store_id ?? 0);
    const kind = String(body?.kind ?? "pending");
    if (!Number.isFinite(storeId) || storeId <= 0) {
      return new Response(JSON.stringify({ error: "Invalid store_id" }), { status: 400 });
    }

    const title = "Nueva solicitud de aprobacion";
    const bodyText = kind === "shift_close"
      ? "Se requiere aprobacion de cierre de caja."
      : "Se requiere aprobacion de movimiento.";

    const payload = {
      title,
      body: bodyText,
      tag: "pending-cashier-approvals",
      route: "pending_approvals",
    };

    let webSent = 0;
    if (vapidPublicKey && vapidPrivateKey) {
      const { data: subs, error: subsErr } = await supabase
        .from("web_push_subscriptions")
        .select("endpoint,p256dh,auth")
        .eq("store_id", storeId)
        .eq("is_active", true);
      if (subsErr) throw subsErr;
      const list = (subs ?? []) as Array<{ endpoint: string; p256dh: string; auth: string }>;
      for (const s of list) {
        try {
          await webpush.sendNotification(
            { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
            JSON.stringify({ ...payload, url: "/" }),
          );
          webSent++;
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
    }

    const fcmSent = await sendFcmToStore(supabase, storeId, payload);

    return new Response(JSON.stringify({ ok: true, web_sent: webSent, fcm_sent: fcmSent }));
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

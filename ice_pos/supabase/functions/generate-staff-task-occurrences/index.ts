// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabase = createClient(supabaseUrl, serviceRoleKey);

function parseTimeToParts(t: string): { h: number; m: number; s: number } {
  const bits = t.split(":").map((x) => Number(x || 0));
  return { h: bits[0] ?? 0, m: bits[1] ?? 0, s: bits[2] ?? 0 };
}

function jsDowToOneToSeven(d: number): number {
  if (d === 0) return 7;
  return d;
}

/** Local calendar parts from UTC instant using Dart-style offset (minutes east of UTC). */
function localPartsFromUtc(utcMs: number, offsetMinutes: number) {
  const localMs = utcMs + offsetMinutes * 60000;
  const d = new Date(localMs);
  return {
    y: d.getUTCFullYear(),
    m: d.getUTCMonth(),
    day: d.getUTCDate(),
    dow: jsDowToOneToSeven(d.getUTCDay()),
  };
}

function localDateTimeToIso(
  y: number,
  m: number,
  day: number,
  h: number,
  min: number,
  s: number,
  offsetMinutes: number,
): string {
  // Build local wall-clock, convert to UTC for timestamptz storage.
  const localMs = Date.UTC(y, m, day, h, min, s) - offsetMinutes * 60000;
  return new Date(localMs).toISOString();
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
    const body = await req.json().catch(() => ({}));
    const horizonDays = Math.max(1, Math.min(2, Number(body?.horizon_days ?? 1)));
    const tzOffsetMinutes = Number(body?.timezone_offset_minutes ?? 0);

    let generated = 0;
    let skipped = 0;

    const { data: templates, error: templatesErr } = await supabase
      .from("staff_task_templates")
      .select("*")
      .eq("is_active", true)
      .limit(500);
    if (templatesErr) throw templatesErr;

    const utcNow = Date.now();

    for (const t of (templates ?? []) as Array<any>) {
      const weekdays = Array.isArray(t.weekdays) ? t.weekdays.map((w: any) => Number(w)) : [];
      const kind = String(t.recurrence_kind ?? "daily");
      const p = parseTimeToParts(String(t.scheduled_time ?? "09:00:00"));
      const notifyBefore = Number(t.notify_minutes_before ?? 15);

      for (let i = 0; i < horizonDays; i++) {
        const base = localPartsFromUtc(utcNow, tzOffsetMinutes);
        const dayUtc = Date.UTC(base.y, base.m, base.day + i);
        const day = localPartsFromUtc(dayUtc, tzOffsetMinutes);
        const match = kind === "daily" || (kind === "weekly" && weekdays.includes(day.dow));
        if (!match) continue;

        const scheduledAtIso = localDateTimeToIso(
          day.y,
          day.m,
          day.day,
          p.h,
          p.m,
          p.s,
          tzOffsetMinutes,
        );
        const scheduledMs = new Date(scheduledAtIso).getTime();
        const notifyAtIso = new Date(scheduledMs - notifyBefore * 60000).toISOString();

        const dayStartIso = localDateTimeToIso(day.y, day.m, day.day, 0, 0, 0, tzOffsetMinutes);
        const dayEndIso = localDateTimeToIso(day.y, day.m, day.day, 23, 59, 59, tzOffsetMinutes);

        const { data: existing, error: existingErr } = await supabase
          .from("staff_tasks")
          .select("id")
          .eq("template_id", t.id)
          .eq("store_id", t.store_id)
          .is("cancelled_at", null)
          .gte("scheduled_at", dayStartIso)
          .lte("scheduled_at", dayEndIso)
          .limit(1);
        if (existingErr) throw existingErr;
        if ((existing ?? []).length > 0) {
          skipped++;
          continue;
        }

        const { data: inserted, error: insErr } = await supabase
          .from("staff_tasks")
          .insert({
            store_id: t.store_id,
            title: t.title,
            description: t.description ?? null,
            scheduled_at: scheduledAtIso,
            notify_at: notifyAtIso,
            created_by_user_id: t.created_by_user_id ?? null,
            created_by_username: t.created_by_username ?? null,
            template_id: t.id,
          })
          .select("id")
          .single();
        if (insErr) throw insErr;
        if (inserted?.id) generated++;
      }
    }

    return new Response(
      JSON.stringify({ ok: true, generated, skipped, horizon_days: horizonDays }),
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

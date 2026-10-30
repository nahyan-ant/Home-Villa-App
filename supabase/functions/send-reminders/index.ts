// Runs every 5 minutes (see the migration's cron job). Tells each maid when a
// task is due and when it is missed, and tells admins about missed medicines.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const TIME_ZONE = "Asia/Dubai";
// Only remind within this many minutes of the moment, so a late run or a
// fresh deploy does not send a pile of old reminders.
const WINDOW = 30;

type Task = {
  series_id: string;
  owner_id: string;
  valid_from: string | null;
  valid_until: string | null;
  start_min: number;
  end_min: number;
  title: string;
  kind: string;
  dose: string | null;
  days: number[];
};

function localNow() {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-GB", {
      timeZone: TIME_ZONE,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      weekday: "short",
      hourCycle: "h23",
    })
      .formatToParts(new Date())
      .map((p) => [p.type, p.value]),
  );
  const weekday = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].indexOf(parts.weekday) + 1;
  return {
    day: `${parts.year}-${parts.month}-${parts.day}`,
    minute: Number(parts.hour) * 60 + Number(parts.minute),
    weekday,
  };
}

function clock(min: number) {
  const h = Math.floor(min / 60) % 24;
  const m = String(min % 60).padStart(2, "0");
  return `${h % 12 === 0 ? 12 : h % 12}:${m} ${h < 12 ? "AM" : "PM"}`;
}

Deno.serve(async (req) => {
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const { data: allowed } = await db.rpc("check_cron_secret", {
    secret: req.headers.get("x-cron-secret") ?? "",
  });
  if (!allowed) return new Response("Forbidden", { status: 403 });

  webpush.setVapidDetails(
    Deno.env.get("VAPID_SUBJECT") ?? "https://homechecklist.nahyan.workers.dev",
    Deno.env.get("VAPID_PUBLIC_KEY")!,
    Deno.env.get("VAPID_PRIVATE_KEY")!,
  );

  const { day, minute, weekday } = localNow();
  const [people, tasks, ticks, work, cover, subs] = await Promise.all([
    db.from("profiles").select("id, name, role, day_off, since, removed_from"),
    db.from("tasks").select("series_id, owner_id, valid_from, valid_until, start_min, end_min, title, kind, dose, days"),
    db.from("ticks").select("series_id").eq("day", day),
    db.from("day_off_work").select("person_id").eq("day", day),
    db.from("night_cover").select("resting_id, covering_id, until_min").eq("day", day),
    db.from("push_subscriptions").select("endpoint, person_id, p256dh, auth"),
  ]);

  const ticked = new Set((ticks.data ?? []).map((t) => t.series_id));
  const working = new Set((work.data ?? []).map((w) => w.person_id));
  const active = (p: { since: string; removed_from: string | null }) =>
    p.since <= day && (p.removed_from === null || p.removed_from > day);
  const maids = new Map(
    (people.data ?? [])
      .filter((p) => p.role === "maid" && active(p))
      .filter((p) => p.day_off !== weekday || working.has(p.id))
      .map((p) => [p.id, p]),
  );
  const admins = (people.data ?? []).filter((p) => p.role === "admin" && active(p)).map((p) => p.id);

  const messages: { to: string; key: string; title: string; body: string }[] = [];
  for (const t of (tasks.data ?? []) as Task[]) {
    if (t.kind === "rest" || !t.days.includes(weekday) || !maids.has(t.owner_id)) continue;
    if (t.valid_from && t.valid_from > day) continue;
    if (t.valid_until && t.valid_until < day) continue;
    if (ticked.has(t.series_id)) continue;

    // After a night emergency the morning goes to whoever covers.
    const c = (cover.data ?? []).find((c) => c.resting_id === t.owner_id && t.start_min < c.until_min);
    const to = c ? c.covering_id : t.owner_id;
    const when = `${clock(t.start_min)} – ${clock(t.end_min)}`;
    const proof = t.kind === "medicine" ? "Give the dose and add a photo." : "Add a photo when it is done.";

    if (minute >= t.start_min && minute < t.end_min && minute - t.start_min <= WINDOW) {
      messages.push({ to, key: `due:${day}:${t.series_id}`, title: `Now: ${t.title}`, body: `${when}. ${proof}` });
    }
    if (minute >= t.end_min && minute - t.end_min <= WINDOW) {
      messages.push({
        to,
        key: `miss:${day}:${t.series_id}`,
        title: `Not done: ${t.title}`,
        body: `It was due by ${clock(t.end_min)}. Do it now and add a photo, or it counts as missed.`,
      });
      if (t.kind === "medicine") {
        const name = maids.get(t.owner_id)?.name ?? "The maid";
        for (const a of admins) {
          messages.push({
            to: a,
            key: `admin-miss:${day}:${t.series_id}:${a}`,
            title: "Medicine not recorded",
            body: `${name}: ${t.title} was due by ${clock(t.end_min)}.`,
          });
        }
      }
    }
  }

  let sent = 0;
  for (const m of messages) {
    // Claim the key first so each reminder goes out only once.
    const { data: claimed } = await db
      .from("reminders_sent")
      .upsert({ key: m.key }, { onConflict: "key", ignoreDuplicates: true })
      .select("key");
    if (!claimed?.length) continue;
    for (const s of (subs.data ?? []).filter((s) => s.person_id === m.to)) {
      try {
        await webpush.sendNotification(
          { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
          JSON.stringify({ title: m.title, body: m.body, tag: m.key }),
        );
        sent++;
      } catch (e) {
        // The phone unsubscribed or the app was removed.
        const code = (e as { statusCode?: number }).statusCode;
        if (code === 404 || code === 410) {
          await db.from("push_subscriptions").delete().eq("endpoint", s.endpoint);
        }
      }
    }
  }
  return new Response(JSON.stringify({ day, minute, checked: messages.length, sent }), {
    headers: { "Content-Type": "application/json" },
  });
});

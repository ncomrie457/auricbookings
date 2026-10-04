// ─────────────────────────────────────────────────────────────────────────────
// Auric Movement — Stripe → auto-confirm reformer bookings
//
// WHAT IT DOES
//   When a Stripe payment succeeds (checkout.session.completed), this function:
//     1. Verifies the event is really from Stripe (signature check).
//     2. Finds the matching UNPAID registration in reformer_registrations
//        (by the payer's email — most recent unpaid row wins).
//     3. Marks that row is_paid = true (paid_at = now).
//     4. Sends the branded confirmation email for that event via EmailJS.
//
//   Covers the reformer-style events only (Riddim & Kompa West Hempstead &
//   Brooklyn, Halloween, Turkey Burn) — the ones that share reformer_registrations.
//   Payments that don't match a reformer row are ignored (returns 200).
//
// SECRETS this function needs (set with `supabase secrets set …`, see WEBHOOK_SETUP.md):
//   STRIPE_SECRET_KEY          Stripe → Developers → API keys → Secret key (sk_live_…)
//   STRIPE_WEBHOOK_SECRET      Stripe → Developers → Webhooks → your endpoint → Signing secret (whsec_…)
//   EMAILJS_PUBLIC_KEY         EmailJS → Account → General → Public Key
//   EMAILJS_PRIVATE_KEY        EmailJS → Account → General → Private Key (a.k.a. access token)
//   (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.)
// ─────────────────────────────────────────────────────────────────────────────
import Stripe from "https://esm.sh/stripe@14?target=deno&deno-std=0.177.0";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", { apiVersion: "2024-06-20" });
const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const EMAILJS_SERVICE = "service_ieahnue";
const EMAILJS_PUBLIC = Deno.env.get("EMAILJS_PUBLIC_KEY") ?? "";
const EMAILJS_PRIVATE = Deno.env.get("EMAILJS_PRIVATE_KEY") ?? "";

// event id → confirmation EmailJS template id (matches the manual "Confirm + email" flow)
const EVENT_TEMPLATE: Record<string, string> = {
  "riddim-kompa-reformer-2026-09-13": "template_pdfnmgu",
  "riddim-kompa-brooklyn-2026-09-26": "template_pq0dq1h",
  "halloween-creek-2026-10-24": "template_hhjwepr",
  // Both Turkey Burn dates share one template; like the Brooklyn one, the date
  // rides in as event_date rather than being written into the HTML.
  "turkey-burn-2026-11-22": "template_96eon3x",
  "turkey-burn-2026-11-28": "template_96eon3x",
  // Every Maison Luxe date shares the Brooklyn template; the date rides in
  // as event_date, so a new Brooklyn date needs no new template.
  "riddim-kompa-brooklyn-2026-10-10": "template_pq0dq1h",
  "riddim-kompa-brooklyn-2026-11-21": "template_pq0dq1h",
};
const RECEIPT_PREFIX: Record<string, string> = {
  "riddim-kompa-reformer-2026-09-13": "RK",
  "riddim-kompa-brooklyn-2026-09-26": "RKBK",
  "halloween-creek-2026-10-24": "HW",
  "turkey-burn-2026-11-22": "TB",
  "turkey-burn-2026-11-28": "TB28",
  "riddim-kompa-brooklyn-2026-10-10": "RKO10",
  "riddim-kompa-brooklyn-2026-11-21": "RKN21",
};
const SESSION_META: Record<string, { time: string; arrival: string; cal: string }> = {
  "1pm":    { time: "1:00 PM",  arrival: "12:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-west-hempstead-1pm" },
  "2pm":    { time: "2:00 PM",  arrival: "1:55 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-west-hempstead-2pm" },
  "3pm":    { time: "3:00 PM",  arrival: "2:55 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-west-hempstead-3pm" },
  "bk12":   { time: "12:00 PM", arrival: "11:55 AM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-brooklyn-12pm" },
  "bk1":    { time: "1:00 PM",  arrival: "12:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-brooklyn-1pm" },
  "bk2":    { time: "2:00 PM",  arrival: "1:55 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-brooklyn-2pm" },
  "tb1130": { time: "11:30 AM", arrival: "11:25 AM", cal: "https://book.auricmovement.com/calendar/add/?e=turkey-burn-1130am" },
  "tb1230": { time: "12:30 PM", arrival: "12:25 PM", cal: "https://book.auricmovement.com/calendar/add/?e=turkey-burn-1230pm" },
  "tb130":  { time: "1:30 PM",  arrival: "1:25 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=turkey-burn-130pm" },
  "tb28_1130": { time: "11:30 AM", arrival: "11:25 AM", cal: "https://book.auricmovement.com/calendar/add/?e=turkey-burn-1128-1130am" },
  "tb28_1230": { time: "12:30 PM", arrival: "12:25 PM", cal: "https://book.auricmovement.com/calendar/add/?e=turkey-burn-1128-1230pm" },
  "tb28_130":  { time: "1:30 PM",  arrival: "1:25 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=turkey-burn-1128-130pm" },
  "hw1130": { time: "11:30 AM", arrival: "11:25 AM", cal: "https://book.auricmovement.com/calendar/add/?e=halloween-1130am" },
  "hw1230": { time: "12:30 PM", arrival: "12:25 PM", cal: "https://book.auricmovement.com/calendar/add/?e=halloween-1230pm" },
  "hw130":  { time: "1:30 PM",  arrival: "1:25 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=halloween-130pm" },
  "o12":     { time: "12:00 PM", arrival: "11:55 AM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-oct10-12pm" },
  "o1":      { time: "1:00 PM", arrival: "12:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-oct10-1pm" },
  "o2":      { time: "2:00 PM", arrival: "1:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-oct10-2pm" },
  "o3":      { time: "3:00 PM", arrival: "2:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-oct10-3pm" },
  "n12":     { time: "12:00 PM", arrival: "11:55 AM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-nov21-12pm" },
  "n1":      { time: "1:00 PM", arrival: "12:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-nov21-1pm" },
  "n2":      { time: "2:00 PM", arrival: "1:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-nov21-2pm" },
  "n3":      { time: "3:00 PM", arrival: "2:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-nov21-3pm" },
};
// Pre- and Post-Turkey Burn share one template, so the email has to be told
// which one it is as well as when.
const EVENT_NAME: Record<string, string> = {
  "turkey-burn-2026-11-22": "Pre-Turkey Burn",
  "turkey-burn-2026-11-28": "Post-Turkey Burn",
};
const EVENT_DATE: Record<string, string> = {
  "riddim-kompa-reformer-2026-09-13": "Sunday, September 13th",
  "riddim-kompa-brooklyn-2026-09-26": "Saturday, September 26th",
  "riddim-kompa-brooklyn-2026-10-10": "Saturday, October 10th",
  "riddim-kompa-brooklyn-2026-11-21": "Saturday, November 21st",
  "halloween-creek-2026-10-24": "Saturday, October 24th",
  "turkey-burn-2026-11-22": "Sunday, November 22nd",
  "turkey-burn-2026-11-28": "Saturday, November 28th",
};
// When each event actually happens. Used to ignore rows for events that are
// already over: a payment landing today is never settling a booking for a class
// that already ran. Without this, a returning guest — and most of them return —
// could have a new payment applied to a leftover unpaid row from a past event,
// and be sent a confirmation for a date that has been and gone.
const EVENT_ON: Record<string, string> = {
  "riddim-kompa-reformer-2026-09-13": "2026-09-13",
  "riddim-kompa-brooklyn-2026-09-26": "2026-09-26",
  "riddim-kompa-brooklyn-2026-10-10": "2026-10-10",
  "halloween-creek-2026-10-24": "2026-10-24",
  "riddim-kompa-brooklyn-2026-11-21": "2026-11-21",
  "turkey-burn-2026-11-22": "2026-11-22",
  "turkey-burn-2026-11-28": "2026-11-28",
};
// Three days of slack, so a Stripe retry for a payment taken on the day of the
// event still finds its row. An event NOT in the map is treated as current: a
// new event whose date nobody added here must not silently stop confirming.
function eventIsOver(event: string, now: Date): boolean {
  const on = EVENT_ON[event];
  if (!on) return false;
  return new Date(on + "T23:59:59-04:00").getTime() < now.getTime() - 3 * 864e5;
}

const REFUND_TEXT = "All sales are final — no refunds or credits. Spot transfers to a friend are welcome up to 24 hours before the event — email auricmovement@outlook.com with both names.";

async function sendConfirmation(row: Record<string, unknown>, amountCents: number) {
  const event = String(row.event ?? "");
  const templateId = EVENT_TEMPLATE[event];
  if (!templateId) return; // not a reformer event we send confirmations for — nothing to send
  if (templateId.startsWith("REPLACE")) {
    // The event is listed but its template was never created, so this buyer
    // would silently get nothing. Throw: Stripe retries, and the log says why.
    throw new Error(`no confirmation template for ${event} — create it and set EVENT_TEMPLATE`);
  }
  // Missing keys is a real misconfiguration: throw so the caller does NOT stamp
  // emailed_at, and Stripe's retry tries again once the keys are restored.
  if (!EMAILJS_PUBLIC || !EMAILJS_PRIVATE) throw new Error("EmailJS keys missing");
  const sess = SESSION_META[String(row.session ?? "")] ?? { time: "", arrival: "", cal: "https://book.auricmovement.com" };
  const amount = amountCents ? `$${(amountCents / 100).toFixed(2)}` : "$45.00";
  const now = new Date().toLocaleString("en-US", { timeZone: "America/New_York" });
  const params = {
    from_name: row.name ?? "there",
    to_email: row.email,
    event_date: EVENT_DATE[event] ?? "",
    event_name: EVENT_NAME[event] ?? "",
    arrival_time: sess.arrival,
    class_time: sess.time,
    calendar_url: sess.cal,
    receipt_amount: amount,
    receipt_code: `${RECEIPT_PREFIX[event] ?? "AURIC"}-${row.id}`,
    receipt_signed_as: row.signature ?? row.name ?? "",
    receipt_signed_at: now,
    refund_policy_ack_at: now,
    refund_policy_text: row.refund_policy_text ?? REFUND_TEXT,
  };
  const res = await fetch("https://api.emailjs.com/api/v1.0/email/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      service_id: EMAILJS_SERVICE,
      template_id: templateId,
      user_id: EMAILJS_PUBLIC,
      accessToken: EMAILJS_PRIVATE,
      template_params: params,
    }),
  });
  // Throw on failure so the caller does NOT stamp emailed_at — the send is
  // retried on Stripe's next delivery attempt instead of being lost.
  if (!res.ok) throw new Error(`EmailJS send failed ${res.status}: ${await res.text()}`);
}

Deno.serve(async (req) => {
  const sig = req.headers.get("stripe-signature");
  const body = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(body, sig ?? "", WEBHOOK_SECRET);
  } catch (err) {
    console.error("Signature verification failed:", (err as Error).message);
    return new Response("Bad signature", { status: 400 });
  }

  if (event.type !== "checkout.session.completed") {
    return new Response("ok (ignored)", { status: 200 });
  }

  const session = event.data.object as Stripe.Checkout.Session;
  if (session.payment_status !== "paid") {
    return new Response("ok (not paid)", { status: 200 });
  }
  const email = (session.customer_details?.email ?? session.customer_email ?? "").trim();
  if (!email) return new Response("ok (no email)", { status: 200 });

  // Find this payer's registrations that still need handling — not yet paid, OR
  // paid but the confirmation was never sent (emailed_at is null). That second
  // case is what lets a Stripe retry deliver an email a failed first attempt lost.
  //
  // Several rows can match one person, so this deliberately fetches a handful
  // rather than one:
  //
  //   • A waitlist row is always unpaid, so it always matches. Fetching a single
  //     row and discarding it if it was a waitlist row meant a waitlist signup
  //     for ANY date could swallow a real payment's confirmation — the function
  //     returned early and the paid booking was never seen. Waitlist and archived
  //     rows are now skipped over rather than being allowed to end the search.
  //
  //   • Ordered OLDEST first. Someone who books two sessions pays for them in the
  //     order they booked far more often than the reverse, and newest-first
  //     attached the first payment's confirmation to the wrong session.
  //
  // The type/archived test stays in code rather than in the query because a
  // confirmed row may store type as null, and a query-level neq drops nulls.
  const { data, error } = await supabase
    .from("reformer_registrations")
    .select("*")
    .ilike("email", email)
    .or("is_paid.eq.false,emailed_at.is.null")
    .order("created_at", { ascending: true })
    .limit(10);

  if (error) { console.error("Supabase query error:", error.message); return new Response("db error", { status: 500 }); }
  const now = new Date();
  const pending = (data ?? []).filter((r) => {
    const rec = r as Record<string, unknown>;
    return String(rec.type ?? "") !== "waitlist" &&
           !rec.archived &&
           !eventIsOver(String(rec.event ?? ""), now);
  });
  // An unpaid booking always wins. A payment that just landed is settling a
  // booking that hasn't been paid for, so take the oldest of those first.
  //
  // Only when nothing is unpaid is this a retry for a confirmation that failed
  // to send, and the paid-but-unemailed row is the right target. Checking in
  // that order matters: a row can sit in paid-but-unemailed indefinitely (a
  // confirmation sent by hand from the admin panel leaves it that way), and
  // picking purely by age would let that stale row absorb every future payment
  // this person makes.
  const row = pending.find((r) => !(r as Record<string, unknown>).is_paid) ??
              pending.find((r) => !(r as Record<string, unknown>).emailed_at);
  if (!row) {
    // Nothing pending — a different event's payment, a waitlist-only signup, or
    // this booking is already paid AND already emailed. Either way, done.
    return new Response("ok (no match)", { status: 200 });
  }

  // 1) Mark paid immediately (idempotent) so it shows paid in your roster right
  //    away, even if the email step below fails and has to retry.
  if (!row.is_paid) {
    const { error: upErr } = await supabase
      .from("reformer_registrations")
      .update({ is_paid: true, paid_at: new Date().toISOString() })
      .eq("id", row.id);
    if (upErr) { console.error("Supabase update error:", upErr.message); return new Response("db update error", { status: 500 }); }
  }

  // 2) Send the confirmation exactly once. If it fails, throw → 500 → Stripe
  //    retries and this runs again (emailed_at still null). Once it succeeds we
  //    stamp emailed_at, so a later retry finds nothing pending and never
  //    double-sends.
  if (!row.emailed_at) {
    try {
      await sendConfirmation(row, session.amount_total ?? 0);
    } catch (e) {
      console.error("sendConfirmation failed (will retry):", (e as Error).message);
      return new Response("email send failed", { status: 500 });
    }
    const { error: stampErr } = await supabase
      .from("reformer_registrations")
      .update({ emailed_at: new Date().toISOString() })
      .eq("id", row.id);
    if (stampErr) console.error("emailed_at stamp failed:", stampErr.message);
  }

  return new Response("ok (confirmed)", { status: 200 });
});

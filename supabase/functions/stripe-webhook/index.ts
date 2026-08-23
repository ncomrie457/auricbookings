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
  "turkey-burn-2026-11-21": "template_96eon3x",
};
const RECEIPT_PREFIX: Record<string, string> = {
  "riddim-kompa-reformer-2026-09-13": "RK",
  "riddim-kompa-brooklyn-2026-09-26": "RKBK",
  "halloween-creek-2026-10-24": "HW",
  "turkey-burn-2026-11-21": "TB",
};
const SESSION_META: Record<string, { time: string; arrival: string; cal: string }> = {
  "1pm":    { time: "1:00 PM",  arrival: "12:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-west-hempstead-1pm" },
  "2pm":    { time: "2:00 PM",  arrival: "1:55 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-west-hempstead-2pm" },
  "bk12":   { time: "12:00 PM", arrival: "11:55 AM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-brooklyn-12pm" },
  "bk1":    { time: "1:00 PM",  arrival: "12:55 PM", cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-brooklyn-1pm" },
  "bk2":    { time: "2:00 PM",  arrival: "1:55 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=riddim-kompa-brooklyn-2pm" },
  "tb1230": { time: "12:30 PM", arrival: "12:25 PM", cal: "https://book.auricmovement.com/calendar/add/?e=turkey-burn-1230pm" },
  "tb130":  { time: "1:30 PM",  arrival: "1:25 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=turkey-burn-130pm" },
  "hw1230": { time: "12:30 PM", arrival: "12:25 PM", cal: "https://book.auricmovement.com/calendar/add/?e=halloween-1230pm" },
  "hw130":  { time: "1:30 PM",  arrival: "1:25 PM",  cal: "https://book.auricmovement.com/calendar/add/?e=halloween-130pm" },
};
const REFUND_TEXT = "All sales are final — no refunds or credits. Spot transfers to a friend are welcome up to 24 hours before the event — email auricmovement@outlook.com with both names.";

async function sendConfirmation(row: Record<string, unknown>, amountCents: number) {
  const event = String(row.event ?? "");
  const templateId = EVENT_TEMPLATE[event];
  if (!templateId) return; // not a reformer event we send confirmations for
  if (!EMAILJS_PUBLIC || !EMAILJS_PRIVATE) { console.warn("EmailJS keys missing — skipping email"); return; }
  const sess = SESSION_META[String(row.session ?? "")] ?? { time: "", arrival: "", cal: "https://book.auricmovement.com" };
  const amount = amountCents ? `$${(amountCents / 100).toFixed(2)}` : "$45.00";
  const now = new Date().toLocaleString("en-US", { timeZone: "America/New_York" });
  const params = {
    from_name: row.name ?? "there",
    to_email: row.email,
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
  if (!res.ok) console.error("EmailJS send failed", res.status, await res.text());
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

  // Find the most recent UNPAID reformer registration for this email.
  const { data, error } = await supabase
    .from("reformer_registrations")
    .select("*")
    .ilike("email", email)
    .eq("is_paid", false)
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) { console.error("Supabase query error:", error.message); return new Response("db error", { status: 500 }); }
  if (!data || data.length === 0) {
    // No matching pending reformer booking (e.g. a different event's payment) — ignore.
    return new Response("ok (no match)", { status: 200 });
  }
  const row = data[0];
  if (row.type === "waitlist") return new Response("ok (waitlist row)", { status: 200 });

  const { error: upErr } = await supabase
    .from("reformer_registrations")
    .update({ is_paid: true, paid_at: new Date().toISOString() })
    .eq("id", row.id);
  if (upErr) { console.error("Supabase update error:", upErr.message); return new Response("db update error", { status: 500 }); }

  try { await sendConfirmation(row, session.amount_total ?? 0); }
  catch (e) { console.error("sendConfirmation threw:", (e as Error).message); }

  return new Response("ok (confirmed)", { status: 200 });
});

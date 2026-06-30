/**
 * Auric Movement — Stripe → Supabase payment confirmation worker
 * ----------------------------------------------------------------
 * Deployed as a Cloudflare Worker. Stripe calls this URL whenever a
 * checkout completes; the worker verifies the request really came from
 * Stripe, reads the booking code we attach to every payment link
 * (`client_reference_id`), and flips that registration's `is_paid` to
 * true in Supabase. That keeps the spot count and the "paid" status
 * accurate automatically, so nobody has to confirm payments by hand.
 *
 * Required secrets / variables (set in the Cloudflare dashboard, see README):
 *   STRIPE_WEBHOOK_SECRET  — "Signing secret" of the Stripe webhook endpoint (whsec_…)
 *   SUPABASE_URL           — https://qvmiwyxerotkqpbuhpun.supabase.co
 *   SUPABASE_SERVICE_KEY   — Supabase service_role key (Project Settings → API)
 *
 * No secret is ever hard-coded here — they all come from `env`.
 */

// Registration tables that may hold the booking. The matching code is unique,
// so a payment only ever lands in one of them; the others update 0 rows.
const TABLES = [
  'matchat_registrations',
  'pilates_registrations',
  'create_recharge_registrations',
];

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // Read the raw body BEFORE parsing — signature verification needs the exact bytes.
    const payload = await request.text();
    const sigHeader = request.headers.get('stripe-signature');

    let event;
    try {
      event = await verifyStripeSignature(payload, sigHeader, env.STRIPE_WEBHOOK_SECRET);
    } catch (err) {
      // 400 tells Stripe the request was rejected (bad/forged signature).
      return new Response('Signature verification failed: ' + err.message, { status: 400 });
    }

    // Only act on a successful checkout. Acknowledge everything else with 200
    // so Stripe doesn't keep retrying events we don't care about.
    const PAID_EVENTS = ['checkout.session.completed', 'checkout.session.async_payment_succeeded'];
    if (!PAID_EVENTS.includes(event.type)) {
      return json({ ignored: event.type }, 200);
    }

    const session = event.data && event.data.object ? event.data.object : {};

    // Don't mark paid if the payment isn't actually settled (e.g. delayed methods).
    if (session.payment_status && session.payment_status !== 'paid') {
      return json({ skipped: 'payment_status=' + session.payment_status }, 200);
    }

    const code = session.client_reference_id || null;
    const email =
      (session.customer_details && session.customer_details.email) ||
      session.customer_email ||
      null;

    if (!code && !email) {
      // Nothing to match on. Acknowledge so Stripe stops retrying.
      return json({ warning: 'no client_reference_id or email on session' }, 200);
    }

    try {
      const matched = await markPaid(env, code, email);
      return json({ ok: true, matchedBy: code ? 'code' : 'email', matched }, 200);
    } catch (err) {
      // 500 → Stripe will retry later, which is what we want on a transient DB error.
      return json({ ok: false, error: err.message }, 500);
    }
  },
};

/**
 * Verify a Stripe webhook signature using the Web Crypto API (no SDK needed).
 * Mirrors Stripe's scheme: signed_payload = `${t}.${rawBody}`, HMAC-SHA256
 * with the endpoint secret, compared against the v1 signature. Also rejects
 * events older than 5 minutes to guard against replay.
 */
async function verifyStripeSignature(payload, sigHeader, secret) {
  if (!secret) throw new Error('STRIPE_WEBHOOK_SECRET is not configured');
  if (!sigHeader) throw new Error('missing stripe-signature header');

  const fields = {};
  sigHeader.split(',').forEach(function (part) {
    const idx = part.indexOf('=');
    if (idx > -1) fields[part.slice(0, idx).trim()] = part.slice(idx + 1).trim();
  });

  const timestamp = fields.t;
  const expected = fields.v1;
  if (!timestamp || !expected) throw new Error('malformed signature header');

  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - parseInt(timestamp, 10)) > 300) {
    throw new Error('timestamp outside tolerance (possible replay)');
  }

  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sigBuf = await crypto.subtle.sign('HMAC', key, enc.encode(timestamp + '.' + payload));
  const computed = [...new Uint8Array(sigBuf)]
    .map(function (b) { return b.toString(16).padStart(2, '0'); })
    .join('');

  if (!timingSafeEqual(computed, expected)) throw new Error('signature mismatch');
  return JSON.parse(payload);
}

// Constant-time string comparison to avoid leaking timing information.
function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Mark the matching registration(s) paid in Supabase via the PostgREST API.
 * Prefers an exact match on the booking code; only falls back to email when
 * no code is present, and even then only updates rows still marked unpaid so
 * it can't clobber unrelated past bookings.
 */
async function markPaid(env, code, email) {
  // Trim to defend against invisible trailing spaces/newlines from copy-paste,
  // and strip any trailing slash on the URL so we never build a double slash.
  const baseUrl = (env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
  const apiKey = (env.SUPABASE_SERVICE_KEY || '').trim();
  if (!baseUrl || !apiKey) {
    throw new Error('SUPABASE_URL / SUPABASE_SERVICE_KEY not configured');
  }

  const nowIso = new Date().toISOString();
  const matched = {};

  for (const table of TABLES) {
    const filter = code
      ? 'code=eq.' + encodeURIComponent(code)
      : 'email=eq.' + encodeURIComponent(email) + '&is_paid=eq.false';

    const resp = await fetch(baseUrl + '/rest/v1/' + table + '?' + filter, {
      method: 'PATCH',
      headers: {
        apikey: apiKey,
        Authorization: 'Bearer ' + apiKey,
        'content-type': 'application/json',
        Prefer: 'return=representation',
      },
      body: JSON.stringify({ is_paid: true, paid_at: nowIso }),
    });

    if (!resp.ok) {
      const detail = await resp.text().catch(function () { return ''; });
      throw new Error(table + ' update failed (' + resp.status + '): ' + detail);
    }

    const rows = await resp.json().catch(function () { return []; });
    matched[table] = Array.isArray(rows) ? rows.length : 0;
  }

  return matched;
}

function json(obj, status) {
  return new Response(JSON.stringify(obj), {
    status: status,
    headers: { 'content-type': 'application/json' },
  });
}

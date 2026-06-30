# Stripe → Supabase payment webhook

This little service makes payments record themselves. When someone completes a
Stripe checkout, Stripe notifies this worker, the worker confirms the request is
genuinely from Stripe, reads the booking code we attach to every payment link
(`client_reference_id`), and marks that registration **paid** (`is_paid = true`)
in Supabase.

Once this is live you no longer have to confirm payments by hand, the spot count
stays accurate on its own, and the 2‑hour auto‑expiry can be safely turned back
on (it will only ever cancel genuinely unpaid holds).

The code is in [`worker.js`](./worker.js). It contains **no secrets** — those
are supplied separately as the 3 values below.

---

## What you'll need (3 secret values)

| Name | Where to get it |
| --- | --- |
| `STRIPE_WEBHOOK_SECRET` | Stripe Dashboard → Developers → Webhooks → your endpoint → **Signing secret** (starts with `whsec_`). You get this *after* step 2 below. |
| `SUPABASE_URL` | `https://qvmiwyxerotkqpbuhpun.supabase.co` |
| `SUPABASE_SERVICE_KEY` | Supabase → Project Settings → API → **`service_role`** key (the secret one, *not* the publishable/anon key). |

> ⚠️ The `service_role` key can read/write your whole database. Only ever paste
> it into the Cloudflare secret field — never into the website, a commit, or an
> email.

---

## Setup (about 10 minutes, all point‑and‑click)

### 1. Create the worker in Cloudflare
1. Log in to **Cloudflare → Workers & Pages → Create → Create Worker**.
2. Give it a name, e.g. `auric-stripe-webhook`. Click **Deploy** (the starter
   code is fine for now).
3. Click **Edit code**, delete everything in the editor, paste in the full
   contents of [`worker.js`](./worker.js), then **Deploy** again.
4. Copy the worker's URL — it looks like
   `https://auric-stripe-webhook.<your-subdomain>.workers.dev`. You'll need it
   in step 2.

### 2. Point Stripe at the worker
1. **Stripe Dashboard → Developers → Webhooks → Add endpoint**.
2. **Endpoint URL:** paste the worker URL from step 1.
3. **Events to send:** select **`checkout.session.completed`** (also add
   **`checkout.session.async_payment_succeeded`** if you offer any delayed
   payment methods).
4. Click **Add endpoint**, then open it and copy the **Signing secret**
   (`whsec_…`) — that's your `STRIPE_WEBHOOK_SECRET`.

### 3. Add the 3 secrets to the worker
1. Back in Cloudflare → your worker → **Settings → Variables and Secrets**.
2. Add each of the three values above. Use **Encrypt / Add secret** (not a plain
   text variable) for `STRIPE_WEBHOOK_SECRET` and `SUPABASE_SERVICE_KEY`.
   `SUPABASE_URL` can be a normal variable.
3. **Deploy** once more so the worker picks up the new values.

### 4. Test it
1. In Stripe → your webhook endpoint → **Send test webhook** →
   `checkout.session.completed`. You should see a **200** response.
2. For a real end‑to‑end check, make a $0.01 test booking (or use Stripe test
   mode), pay, and confirm the registration flips to **paid** in your admin
   panel within a few seconds.
3. If something fails, Cloudflare → your worker → **Logs** ("Begin log stream")
   shows the exact error, and Stripe → webhook → **Recent deliveries** shows the
   response code.

---

## After it's verified working

Tell me and I'll re‑enable the 2‑hour auto‑expiry sweep in `index.html` (it was
disabled because, without this webhook, it was cancelling paid bookings). With
payments recording reliably, the sweep becomes safe again and will only clear
genuinely unpaid holds.

---

## How matching works (FYI)

The booking code (e.g. `AUR-AB12CD`) is attached to every Stripe payment link as
`client_reference_id`, so the worker updates the **exact** registration. The
codes are unique across events, so the worker simply checks all three
registration tables (`matchat_registrations`, `pilates_registrations`,
`create_recharge_registrations`); only the one holding that code is updated.
Email is used only as a fallback if a payment ever arrives without a code.

# Auto-confirm payments — setup guide

This turns on **automatic** confirmation: the moment a Stripe payment succeeds,
the person is marked **paid** in your admin roster and gets your branded
confirmation email — with no clicking from you.

It's a one-time setup. You'll need a computer (Mac or Windows) and about 20–30
minutes. Follow it top to bottom. If anything errors, copy the message and send
it to me.

---

## What you're setting up (plain English)
Your website can't "listen" for Stripe payments on its own, so we add a tiny
helper (a **Supabase Edge Function**) that Stripe pings every time someone pays.
The helper marks that person paid and sends the confirmation email.

---

## Step 1 — Install the tools (one time)
1. Install **Node.js** (LTS) from https://nodejs.org — just click through the installer.
2. Open **Terminal** (Mac: Cmd+Space, type "Terminal") or **PowerShell** (Windows).
3. Install the Supabase CLI:
   ```
   npm install -g supabase
   ```

## Step 2 — Get the project code
```
git clone https://github.com/ncomrie457/auricbookings.git
cd auricbookings
```

## Step 3 — Log in and link your Supabase project
```
supabase login
```
(A browser opens — approve it.) Then link to your project:
```
supabase link --project-ref qvmiwyxerotkqpbuhpun
```

## Step 4 — Add the secret keys
Run each line below, pasting your real values where shown. (Right-click to paste
in the terminal.)

```
supabase secrets set STRIPE_SECRET_KEY=sk_live_XXXXXXXX
supabase secrets set EMAILJS_PUBLIC_KEY=XXXXXXXX
supabase secrets set EMAILJS_PRIVATE_KEY=XXXXXXXX
```
Where to find each:
- **STRIPE_SECRET_KEY** — Stripe dashboard → Developers → API keys → "Secret key" (starts with `sk_live_`). Click "Reveal".
- **EMAILJS_PUBLIC_KEY** and **EMAILJS_PRIVATE_KEY** — EmailJS → Account → General → Public Key / Private Key.

(We add the Stripe **webhook** secret in Step 7.)

## Step 5 — Turn on EmailJS for servers
EmailJS blocks server sending by default. In EmailJS → **Account → Security**,
turn ON **"Allow EmailJS API for non-browser applications"**. Save.

## Step 6 — Deploy the helper
```
supabase functions deploy stripe-webhook --no-verify-jwt
```
When it finishes it prints a URL like:
```
https://qvmiwyxerotkqpbuhpun.supabase.co/functions/v1/stripe-webhook
```
Copy that URL — you need it next.

## Step 7 — Point Stripe at it
1. Stripe dashboard → **Developers → Webhooks → Add endpoint**.
2. **Endpoint URL:** paste the URL from Step 6.
3. **Events to send:** click "Select events" → search **`checkout.session.completed`** → add it.
4. Click **Add endpoint**.
5. On the new endpoint's page, find **"Signing secret"** → Reveal → copy it (starts with `whsec_`).
6. Back in the terminal, save it:
   ```
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_XXXXXXXX
   ```
7. Redeploy so it picks up the secret:
   ```
   supabase functions deploy stripe-webhook --no-verify-jwt
   ```

## Step 8 — Make sure Stripe collects the email
Each of your Payment Links must ask for the customer's email (that's how we match
the payment to the booking). In Stripe → Payment Links, open each link → confirm
**email is collected** (it is by default on Payment Links). Nothing to change if so.

---

## Test it
1. Book a spot on the live site with a **test email you control**, choose a session,
   reach the payment step, and pay (a real $45 charge — you can refund it in Stripe after).
2. Within a few seconds: that person should flip to **paid** in your admin roster,
   and the **confirmation email** should arrive.
3. If it doesn't: Supabase dashboard → Edge Functions → `stripe-webhook` → **Logs**
   shows what happened. Send me the log line.

---

## Good to know
- **Matching is by email.** If a customer pays with a different email than they
  booked with, the auto-match won't find them — you'd just confirm that one by hand
  (the manual "Confirm + email" button still works as always).
- **Your manual button still works** for any edge case.
- **Only reformer events** (Riddim & Kompa West Hempstead + Brooklyn, Halloween,
  Turkey Burn) are auto-confirmed. Other events' payments are safely ignored.
- To change confirmation wording, edit the EmailJS templates as usual — the function
  just triggers them.

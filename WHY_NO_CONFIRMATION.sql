-- ═══════════════════════════════════════════════════════════════════════════
--  Why didn't someone get their confirmation email after paying?
--
--  HOW THE CONFIRMATION ACTUALLY GETS SENT
--    Paying does NOT send the email from the website. The page you land on
--    after Stripe only shows the "you're confirmed" screen — it writes nothing
--    to the server and sends nothing.
--
--    The email comes from the Stripe webhook (supabase/functions/stripe-webhook).
--    When Stripe reports a completed payment it:
--      1. takes the email address STRIPE has for the payer,
--      2. finds that person's most recent registration still needing handling,
--      3. sets is_paid = true, paid_at = now,
--      4. sends the confirmation, then stamps emailed_at.
--
--    So the two columns together tell you where it stopped:
--
--      is_paid = false                 → the webhook never matched her at all
--      is_paid = true, emailed_at NULL → matched and marked paid, email FAILED
--      is_paid = true, emailed_at set  → it DID send; check spam / wrong address
--
--  HOW TO RUN: Supabase → SQL Editor → paste → Run.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1) FIND HER. Change the name if the spelling differs.
select id, name, email, event, session, session_label,
       is_paid, paid_at, emailed_at, type, archived, created_at,
       case
         when coalesce(type,'') = 'waitlist'   then 'waitlist row — never pays, never confirmed'
         when not is_paid                      then '>>> WEBHOOK NEVER MATCHED HER <<<'
         when is_paid and emailed_at is null   then '>>> PAID, BUT THE EMAIL FAILED <<<'
         else 'confirmation was sent ' || emailed_at
       end as what_happened
from public.reformer_registrations
where name ilike '%kamaye%'
order by created_at desc;

-- 2) IF IT SAYS "WEBHOOK NEVER MATCHED HER":
--    Almost always the email on the booking form differs from the email she
--    paid with — a typo, or Apple Pay / Link / PayPal supplying a different
--    address. The webhook matches on the Stripe email, so a mismatch means it
--    looks for a row that isn't there, shrugs, and returns "ok (no match)".
--
--    Confirm it in Stripe: Developers → Webhooks → your endpoint → look for her
--    payment. "ok (no match)" in the response body is the fingerprint.
--    Then compare that payer email against the address in the query above.

-- 3) IF IT SAYS "PAID, BUT THE EMAIL FAILED":
--    The webhook returned 500 and Stripe retried for up to 3 days, then stopped.
--    Supabase → Edge Functions → stripe-webhook → Logs has the reason, usually
--    missing EmailJS keys or a template id that doesn't exist.

-- 4) ANYONE ELSE THIS HAS QUIETLY HAPPENED TO.
--    Run this regardless — it is the same failure, and it is silent, so there is
--    no other way to notice. Paid people who never got their email:
select id, name, email, event, session_label, paid_at
from public.reformer_registrations
where is_paid
  and emailed_at is null
  and coalesce(type,'') <> 'waitlist'
  and not coalesce(archived, false)
order by paid_at desc;

-- 5) PEOPLE WHO MAY HAVE PAID BUT ARE STILL MARKED UNPAID.
--    Cross-check these names against your Stripe payments list. Anyone who
--    appears in Stripe but is false here fell through the email-matching gap.
select id, name, email, event, session_label, created_at
from public.reformer_registrations
where not is_paid
  and coalesce(type,'') <> 'waitlist'
  and not coalesce(archived, false)
  and event in ('riddim-kompa-brooklyn-2026-10-10',
                'halloween-creek-2026-10-24',
                'riddim-kompa-brooklyn-2026-11-21',
                'turkey-burn-2026-11-22',
                'turkey-burn-2026-11-28')
order by created_at desc;

-- ───────────────────────────────────────────────────────────────────────────
--  FIXING IT FOR HER, once you know which it was
--
--  Easiest: open the admin panel, find her on the roster, and use the
--  "Confirm + email" button. That sends the same branded confirmation and
--  marks her paid in one go — no SQL needed.
--
--  If you do it by hand instead, stamp emailed_at too, or the next Stripe
--  retry could send her a second copy:
--
--    update public.reformer_registrations
--       set is_paid = true,
--           paid_at = coalesce(paid_at, now()),
--           emailed_at = now()
--     where id = <her id>;
--
--  And if the cause was a mistyped email, correct the address FIRST, so the
--  confirmation goes somewhere she can read it.
-- ───────────────────────────────────────────────────────────────────────────

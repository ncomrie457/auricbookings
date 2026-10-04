-- ═══════════════════════════════════════════════════════════════════════════
--  Let the admin panel record that a confirmation was sent by hand.
--
--  WHY
--    reformer_registrations.emailed_at is how the Stripe webhook knows whether
--    a buyer has been sent their confirmation. It sends only while that column
--    is null, and stamps it once the email is away, which is what stops a
--    Stripe retry sending someone a second copy.
--
--    The admin panel's "Confirm + email" button sends the same confirmation,
--    but had no way to stamp the column — reformer_set_paid only sets is_paid.
--    So anyone confirmed by hand stayed, permanently, in the state "paid, but
--    never emailed". Two consequences:
--
--      • The query that finds people whose confirmation genuinely went missing
--        fills up with people who were in fact emailed, until it is useless.
--      • The webhook still believes it owes them an email.
--
--    This adds the missing setter. Owner-only, like every other reformer write.
--
--  WHEN TO RUN: once, in Supabase → SQL Editor. Safe to re-run.
--  Pairs with the admin panel change — run this first, or the button logs a
--  warning to the console and carries on (the person is still marked paid).
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.reformer_mark_emailed(
  pass text,
  rid  bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;

  -- coalesce, not a plain assignment: if a confirmation really did go out
  -- earlier, that is when it happened, and overwriting it would lose the fact.
  update public.reformer_registrations
     set emailed_at = coalesce(emailed_at, now())
   where id = rid;
end;
$$;

revoke all on function public.reformer_mark_emailed(text, bigint) from public, anon;

-- ─── Clean up the rows already stuck in that state ─────────────────────────
--
-- Everyone you have confirmed by hand up to now is sitting at "paid, but never
-- emailed". Look at them FIRST — this list is a mix of two different things:
--
--   • people you confirmed yourself, who DID get their email      → stamp them
--   • people whose confirmation genuinely failed to send          → do NOT
--
-- Only you can tell which is which.
select id, name, email, event, session_label, paid_at
from public.reformer_registrations
where is_paid
  and emailed_at is null
  and coalesce(type,'') <> 'waitlist'
  and not coalesce(archived, false)
order by paid_at;

-- Then, for each one you know you emailed yourself, stamp it so it stops
-- showing up (replace the ids):
--
--   update public.reformer_registrations
--      set emailed_at = coalesce(paid_at, now())
--    where id in (00, 00);
--
-- Leave anyone whose email actually failed — they still need sending, and the
-- admin panel's "Confirm + email" button will now stamp them as it goes.

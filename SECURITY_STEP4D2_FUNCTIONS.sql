-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Security Step 4d-2, PART A: move public UPDATEs to
--  server functions (so public UPDATE can then be revoked).
--
--  The only public update paths left are on pilates/mat & chat/create &
--  recharge: the hold-expiry sweep, and create & recharge's referral +
--  waiver-completion + Stripe-return payment marks. Each becomes a narrow
--  server function so the broad "anyone can update any row" grant can go away.
--
--  ▶ PART A is additive/safe. Run it, then the site is switched to use these,
--    then PART B revokes public UPDATE.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

-- Cancel expired unpaid holds (pilates + mat & chat), server-side.
create or replace function public.sweep_expired_holds()
returns void language sql security definer set search_path = public as $$
  update public.pilates_registrations set type='cancelled'
    where is_paid = false and type = 'confirmed' and expires_at < now();
  update public.matchat_registrations set type='cancelled'
    where is_paid = false and type = 'confirmed' and expires_at < now();
$$;

-- Create & Recharge: record a referral on the pending row (by code).
create or replace function public.crecharge_set_referral(p_code text, p_referral text)
returns void language sql security definer set search_path = public as $$
  update public.create_recharge_registrations
     set referred_by = p_referral
   where code = p_code;
$$;

-- Create & Recharge: complete the waiver on an already-paid pending row.
create or replace function public.crecharge_complete_waiver(
  p_code text, p_name text, p_phone text, p_signature text,
  p_clauses int, p_notes text, p_referral text)
returns void language sql security definer set search_path = public as $$
  update public.create_recharge_registrations
     set name           = coalesce(p_name, name),
         phone          = p_phone,
         signature      = p_signature,
         clauses_agreed = p_clauses,
         notes          = p_notes,
         referred_by    = nullif(p_referral, ''),
         is_paid        = true,
         paid_at        = now()
   where code = p_code;
$$;

-- Create & Recharge: mark paid on return from Stripe (by code).
create or replace function public.crecharge_mark_paid(p_code text)
returns void language sql security definer set search_path = public as $$
  update public.create_recharge_registrations
     set is_paid = true, paid_at = now()
   where code = p_code;
$$;

grant execute on function public.sweep_expired_holds()                         to anon, authenticated;
grant execute on function public.crecharge_set_referral(text,text)             to anon, authenticated;
grant execute on function public.crecharge_complete_waiver(text,text,text,text,int,text,text) to anon, authenticated;
grant execute on function public.crecharge_mark_paid(text)                     to anon, authenticated;

select 'Step 4d-2 Part A functions created.' as status;

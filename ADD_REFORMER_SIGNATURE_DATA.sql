-- ══════════════════════════════════════════════════════════════════
--  Wet (drawn) signatures for reformer bookings
--  Riddim & Kompa (West Hempstead + Brooklyn) and Turkey Burn store a
--  drawn signature as a base64 PNG data URL in this column.
--  Bookings work with or without this column (the site inserts safely
--  either way) — run this so the drawn signature is actually saved.
-- ══════════════════════════════════════════════════════════════════
alter table public.reformer_registrations
  add column if not exists signature_data text;

-- OPTIONAL: if your reformer_roster() function SELECTs columns explicitly
-- (rather than SELECT *), add signature_data to its returned columns so the
-- drawn signature shows in the admin "📄 Waiver" PDF. If it uses SELECT *,
-- nothing else is needed.

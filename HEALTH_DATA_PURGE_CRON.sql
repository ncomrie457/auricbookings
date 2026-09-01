-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — automatic 48-hour purge of health / notes data
--
--  Makes the site's "we delete your health info after 48 hours" claim
--  automatically true. A pg_cron job runs HOURLY and NULLs the health /
--  notes fields on any record older than 48 hours, across every table that
--  collects them. The manual "Clear Health" buttons still work for clearing
--  something early — this is just the automatic backstop.
--
--  Fields cleared (participant-submitted health disclosures only — admin_notes
--  is left alone since it is your own operational notes):
--    reformer_registrations . health
--    pilates_registrations  . notes
--    matchat_registrations  . notes
--    standalone_waivers     . notes
--    corporate_inquiries    . injuries, additional_notes
--    corporate_bookings     . injuries
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
--  (If pg_cron isn't enabled yet: Dashboard → Database → Extensions →
--   enable "pg_cron", then run this. The create extension line below also
--   enables it when you have permission.)
-- ════════════════════════════════════════════════════════════════════

create extension if not exists pg_cron;

-- ── The purge function ──────────────────────────────────────────────
create or replace function public.purge_old_health_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  cutoff timestamptz := now() - interval '48 hours';
begin
  -- Each table is wrapped on its own so a surprise (a missing column, a
  -- renamed table) skips that one table instead of aborting the whole purge.
  begin
    update public.reformer_registrations set health = null
     where health is not null and created_at < cutoff;
  exception when undefined_table or undefined_column then raise notice 'skip reformer_registrations: %', sqlerrm; end;

  begin
    update public.pilates_registrations set notes = null
     where notes is not null and created_at < cutoff;
  exception when undefined_table or undefined_column then raise notice 'skip pilates_registrations: %', sqlerrm; end;

  begin
    update public.matchat_registrations set notes = null
     where notes is not null and created_at < cutoff;
  exception when undefined_table or undefined_column then raise notice 'skip matchat_registrations: %', sqlerrm; end;

  begin
    update public.standalone_waivers set notes = null
     where notes is not null and created_at < cutoff;
  exception when undefined_table or undefined_column then raise notice 'skip standalone_waivers: %', sqlerrm; end;

  begin
    update public.corporate_inquiries set injuries = null, additional_notes = null
     where (injuries is not null or additional_notes is not null) and created_at < cutoff;
  exception when undefined_table or undefined_column then raise notice 'skip corporate_inquiries: %', sqlerrm; end;

  begin
    update public.corporate_bookings set injuries = null
     where injuries is not null and created_at < cutoff;
  exception when undefined_table or undefined_column then raise notice 'skip corporate_bookings: %', sqlerrm; end;
end;
$$;

-- Only the database roles run this; no anon/authenticated access needed.
revoke all on function public.purge_old_health_data() from anon, authenticated;

-- ── Schedule it hourly ──────────────────────────────────────────────
-- Remove any existing job of the same name first (safe to re-run this file).
do $$
begin
  perform cron.unschedule('purge-old-health-data');
exception when others then
  null;  -- no existing job; ignore
end $$;

select cron.schedule(
  'purge-old-health-data',
  '0 * * * *',                                   -- top of every hour
  $$ select public.purge_old_health_data(); $$
);

-- Run it once now so anything already older than 48h is cleared immediately.
select public.purge_old_health_data();

select 'Health-data purge scheduled — runs hourly, clears health/notes older than 48h.' as status;

-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — self-serve "Add Event" (announcement / RSVP events)
--
--  Lets the owner publish a new event from the admin panel (flyer + details)
--  that appears on the site as a card with an RSVP / interest signup — no
--  Stripe, no waiver. When an event is ready to take card payments, that gets
--  wired into the code separately.
--
--  Two tables:
--    custom_events        — the event (flyer stored as a compressed data URL)
--    custom_event_rsvps   — who signed up
--
--  Security: anyone can SEE a published event and RSVP to it. Only the owner
--  (is_owner()) can create/edit/delete events or read the RSVP list.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

create table if not exists public.custom_events (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz default now(),
  title        text not null,
  subtitle     text,
  event_date   date,
  time_text    text,
  location     text,
  price_text   text,
  description  text,
  flyer_data   text,                      -- base64 data URL (compressed client-side)
  cta_type     text default 'rsvp',       -- 'rsvp' | 'external'
  external_url text,
  published    boolean default true
);

create table if not exists public.custom_event_rsvps (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  event_id   uuid references public.custom_events(id) on delete cascade,
  name       text,
  email      text,
  note       text
);

alter table public.custom_events      enable row level security;
alter table public.custom_event_rsvps enable row level security;

-- ── custom_events ──────────────────────────────────────────────────
-- Public sees only published events.
drop policy if exists ce_public_read on public.custom_events;
create policy ce_public_read on public.custom_events
  for select using (published = true);

-- Owner has full control (including unpublished drafts).
drop policy if exists ce_owner_all on public.custom_events;
create policy ce_owner_all on public.custom_events
  for all to authenticated
  using (public.is_owner()) with check (public.is_owner());

-- ── custom_event_rsvps ─────────────────────────────────────────────
-- Anyone can RSVP.
drop policy if exists cer_public_insert on public.custom_event_rsvps;
create policy cer_public_insert on public.custom_event_rsvps
  for insert to anon, authenticated with check (true);

-- Only the owner can read / delete RSVPs.
drop policy if exists cer_owner_read on public.custom_event_rsvps;
create policy cer_owner_read on public.custom_event_rsvps
  for select to authenticated using (public.is_owner());
drop policy if exists cer_owner_del on public.custom_event_rsvps;
create policy cer_owner_del on public.custom_event_rsvps
  for delete to authenticated using (public.is_owner());

grant select                       on public.custom_events      to anon, authenticated;
grant insert, update, delete       on public.custom_events      to authenticated;
grant insert                       on public.custom_event_rsvps to anon, authenticated;
grant select, delete               on public.custom_event_rsvps to authenticated;

select 'custom_events + custom_event_rsvps ready — the Add Event tab now works.' as status;

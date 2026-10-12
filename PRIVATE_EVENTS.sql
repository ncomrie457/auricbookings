-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — private events behind an access code
--
--  THE PROBLEM THIS SOLVES: book.auricmovement.com is built from a
--  PUBLIC GitHub repository. Anyone can read every line of it. So a
--  code written into the website — even scrambled, even hashed — is a
--  code anyone can find or crack offline in seconds. It would look
--  private and not be.
--
--  So the code lives HERE instead, in the database, and the website
--  only ever asks the question. The repo contains the name of this
--  function and nothing else. There is no secret in it to find.
--
--  WHAT A GUEST CAN DO
--    Hold the code -> see that one event and reserve a spot.
--    Not hold the code -> see nothing. No list, no titles, no hint
--    that a given code exists.
--    Even holding the code, a guest NEVER sees the other guests. The
--    page gets a number of spots left, not a roster.
--
--  HOW SAFE IS A SHORT CODE? Honestly: a short word is guessable by
--  someone determined, and this cannot rate-limit them. What they would
--  reach is a birthday party page — a date, a time and a studio — not
--  anybody's personal data. Use a code you are happy for a stranger to
--  stumble on, and if you want it genuinely hard to guess, make it
--  longer. A reserved spot still has to give a real name and email.
--
--  WHAT THIS CREATES
--    1) private_events            — one row per private event.
--    2) private_event_rsvps       — who is coming, with the same waiver,
--                                   refund acknowledgement and health
--                                   disclosures the public bookings take,
--                                   plus food allergies for the desserts.
--    3) auric_private_get(code)   — PUBLIC. One event, by exact code.
--    4) auric_private_rsvp(...)   — PUBLIC. Reserves a spot.
--    5) auric_private_list()      — owner only. Every event.
--    6) auric_private_rsvps(code) — owner only. The guest list.
--    7) auric_private_save(...)   — owner only. Create or update one.
--    8) auric_private_delete(...) — owner only.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

-- 1) The events ───────────────────────────────────────────────────────
create table if not exists public.private_events (
  id           bigint generated always as identity primary key,
  code         text not null unique,      -- stored lower-cased; compared lower-cased
  title        text not null,
  host_name    text,                      -- "Fainola", for "you're invited to celebrate ..."
  blurb        text,
  event_date   text,                      -- free text: "Saturday, November 21"
  event_time   text,                      -- "4:30 PM"
  venue_name   text,
  venue_address text,
  price_text   text,                      -- "$45 per person", or null to show nothing
  flyer_url    text,                      -- the invitation image, shown at the top of the page
  pay_url      text,                      -- a Stripe payment link, kept out of the repo
  capacity     int,                       -- null = no limit
  closes_at    date,                      -- after this, reservations stop
  active       boolean not null default true,
  created_at   timestamptz not null default now()
);

create table if not exists public.private_event_rsvps (
  id          bigint generated always as identity primary key,
  event_code  text not null references public.private_events(code) on delete cascade,
  name        text not null,
  email       text not null,
  phone       text,
  guests      int not null default 1,     -- how many they are bringing, including themselves
  note        text,
  -- There are desserts afterwards, so allergies are not optional politeness.
  food_allergies text,
  -- Same disclosures the public bookings take, so a private guest is not a
  -- thinner record than a paying one.
  health      text,
  signature   text,                       -- typed name on the waiver
  initials    text,                       -- initialled against the refund policy
  refund_ack  boolean not null default false,
  signed_at   timestamptz,
  is_paid     boolean not null default false,
  admin_notes text,
  created_at  timestamptz not null default now()
);

create index if not exists private_events_code_idx on public.private_events (code);
create index if not exists private_rsvps_code_idx  on public.private_event_rsvps (event_code);

-- Nothing reaches these tables directly. The functions below decide what
-- a stranger holding a code is allowed to learn.
alter table public.private_events      enable row level security;
alter table public.private_event_rsvps enable row level security;

-- Helper: spots already taken, counting each guest in a party.
create or replace function public.auric_private_taken(p_code text)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(greatest(guests, 1)), 0)::int
    from public.private_event_rsvps
   where event_code = lower(trim(p_code));
$$;

-- Dropped first on purpose: "create or replace" cannot change a function's
-- output columns or argument list, so without these a second run of this
-- file after any edit fails with "cannot change return type".
drop function if exists public.auric_private_get(text);
drop function if exists public.auric_private_save(text,text,text,text,text,text,text,text,text,text,text,int,date,boolean);
drop function if exists public.auric_private_save(text,text,text,text,text,text,text,text,text,text,text,text,int,date,boolean);
drop function if exists public.auric_private_rsvp(text,text,text,text,int,text);
drop function if exists public.auric_private_rsvp(text,text,text,text,int,text,text,text,text,text);
drop function if exists public.auric_private_list(text);

-- 2) Read one event by its code — PUBLIC ──────────────────────────────
--    Deliberately returns NO guest details: a number of spots left, and
--    nothing about who took the others.
create or replace function public.auric_private_get(p_code text)
returns table (
  code text, title text, host_name text, blurb text,
  event_date text, event_time text, venue_name text, venue_address text,
  price_text text, pay_url text, flyer_url text,
  spots_left int, closed boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  key text := lower(trim(coalesce(p_code, '')));
begin
  if key = '' then return; end if;

  return query
    select e.code, e.title, e.host_name, e.blurb,
           e.event_date, e.event_time, e.venue_name, e.venue_address,
           e.price_text, e.pay_url, e.flyer_url,
           case when e.capacity is null then null
                else greatest(e.capacity - public.auric_private_taken(e.code), 0) end as spots_left,
           (not e.active)
             or (e.closes_at is not null and e.closes_at < current_date)
             or (e.capacity is not null and public.auric_private_taken(e.code) >= e.capacity) as closed
      from public.private_events e
     where e.code = key
       and e.active;          -- a switched-off event reads as if it never existed
end;
$$;

-- 3) Reserve a spot — PUBLIC ──────────────────────────────────────────
create or replace function public.auric_private_rsvp(
  p_code  text,
  p_name  text,
  p_email text,
  p_phone text default null,
  p_guests int default 1,
  p_note  text default null,
  p_allergies text default null,
  p_health    text default null,
  p_signature text default null,
  p_initials  text default null
)
returns int                                  -- spots left afterwards, or -1 for unlimited
language plpgsql
security definer
set search_path = public
as $$
declare
  ev    public.private_events%rowtype;
  party int := greatest(coalesce(p_guests, 1), 1);
  taken int;
begin
  select * into ev from public.private_events
   where code = lower(trim(coalesce(p_code, ''))) and active;
  if not found then
    raise exception 'that code does not match an open event';
  end if;

  if coalesce(trim(p_name), '') = '' then
    raise exception 'a name is required';
  end if;
  if coalesce(trim(p_email), '') !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'a valid email address is required';
  end if;
  if ev.closes_at is not null and ev.closes_at < current_date then
    raise exception 'reservations for this one have closed';
  end if;
  if party > 10 then
    raise exception 'that is a lot of guests — email us and we will sort it out';
  end if;

  taken := public.auric_private_taken(ev.code);
  if ev.capacity is not null and taken + party > ev.capacity then
    raise exception '%', case
      when ev.capacity - taken <= 0 then 'this one is full'
      when ev.capacity - taken = 1  then 'there is only 1 spot left'
      else 'there are only ' || (ev.capacity - taken) || ' spots left'
    end;
  end if;

  if coalesce(trim(p_signature), '') = '' then
    raise exception 'the waiver has to be signed';
  end if;

  insert into public.private_event_rsvps (
    event_code, name, email, phone, guests, note,
    food_allergies, health, signature, initials, refund_ack, signed_at
  ) values (
    ev.code, trim(p_name), lower(trim(p_email)), nullif(trim(p_phone), ''),
    party, nullif(trim(p_note), ''),
    nullif(trim(p_allergies), ''), nullif(trim(p_health), ''),
    trim(p_signature), upper(nullif(trim(p_initials), '')), true, now()
  );

  if ev.capacity is null then return -1; end if;
  return greatest(ev.capacity - public.auric_private_taken(ev.code), 0);
end;
$$;

-- 4) Owner: every event, including the switched-off ones ──────────────
create or replace function public.auric_private_list(pass text default '')
returns table (
  code text, title text, host_name text, event_date text, event_time text,
  venue_name text, capacity int, closes_at date, active boolean,
  taken int, created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then raise exception 'not authorized'; end if;
  return query
    select e.code, e.title, e.host_name, e.event_date, e.event_time,
           e.venue_name, e.capacity, e.closes_at, e.active,
           public.auric_private_taken(e.code), e.created_at
      from public.private_events e
     order by e.created_at desc;
end;
$$;

-- 5) Owner: the guest list for one event ──────────────────────────────
create or replace function public.auric_private_rsvps(pass text, p_code text)
returns setof public.private_event_rsvps
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then raise exception 'not authorized'; end if;
  return query
    select * from public.private_event_rsvps
     where event_code = lower(trim(p_code))
     order by created_at;
end;
$$;

-- 6) Owner: create one, or update it by re-using the same code ────────
create or replace function public.auric_private_save(
  pass          text,
  p_code        text,
  p_title       text,
  p_host        text default null,
  p_blurb       text default null,
  p_date        text default null,
  p_time        text default null,
  p_venue       text default null,
  p_address     text default null,
  p_price       text default null,
  p_pay_url     text default null,
  p_flyer_url   text default null,
  p_capacity    int default null,
  p_closes_at   date default null,
  p_active      boolean default true
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  key text := lower(trim(coalesce(p_code, '')));
begin
  if not public.is_owner() then raise exception 'not authorized'; end if;
  if length(key) < 4 then
    raise exception 'use a code of at least 4 characters';
  end if;
  if key ~ '[[:space:]]' then
    raise exception 'the code cannot contain spaces — it has to survive being typed into a URL';
  end if;
  if coalesce(trim(p_title), '') = '' then
    raise exception 'the event needs a title';
  end if;

  insert into public.private_events (
    code, title, host_name, blurb, event_date, event_time,
    venue_name, venue_address, price_text, pay_url, flyer_url, capacity, closes_at, active
  ) values (
    key, trim(p_title), nullif(trim(p_host), ''), nullif(trim(p_blurb), ''),
    nullif(trim(p_date), ''), nullif(trim(p_time), ''), nullif(trim(p_venue), ''),
    nullif(trim(p_address), ''), nullif(trim(p_price), ''), nullif(trim(p_pay_url), ''),
    nullif(trim(p_flyer_url), ''), p_capacity, p_closes_at, coalesce(p_active, true)
  )
  on conflict (code) do update set
    title = excluded.title, host_name = excluded.host_name, blurb = excluded.blurb,
    event_date = excluded.event_date, event_time = excluded.event_time,
    venue_name = excluded.venue_name, venue_address = excluded.venue_address,
    price_text = excluded.price_text, pay_url = excluded.pay_url,
    flyer_url = excluded.flyer_url,
    capacity = excluded.capacity, closes_at = excluded.closes_at, active = excluded.active;

  return key;
end;
$$;

-- 7) Owner: delete one, and its guest list with it ────────────────────
create or replace function public.auric_private_delete(pass text, p_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then raise exception 'not authorized'; end if;
  delete from public.private_events where code = lower(trim(p_code));
end;
$$;

-- 8) Who may call what ────────────────────────────────────────────────
revoke all on function public.auric_private_list(text)                      from public, anon;
revoke all on function public.auric_private_rsvps(text, text)               from public, anon;
revoke all on function public.auric_private_delete(text, text)              from public, anon;
revoke all on function public.auric_private_save(text,text,text,text,text,text,text,text,text,text,text,text,int,date,boolean) from public, anon;

grant execute on function public.auric_private_list(text)                   to authenticated;
grant execute on function public.auric_private_rsvps(text, text)            to authenticated;
grant execute on function public.auric_private_delete(text, text)           to authenticated;
grant execute on function public.auric_private_save(text,text,text,text,text,text,text,text,text,text,text,text,int,date,boolean) to authenticated;

-- The guest holding the code is not signed in. Both of these are scoped to
-- a single event by exact code, and neither returns anybody's details.
grant execute on function public.auric_private_get(text) to anon, authenticated;
grant execute on function public.auric_private_rsvp(text, text, text, text, int, text, text, text, text, text) to anon, authenticated;
grant execute on function public.auric_private_taken(text) to anon, authenticated;

select 'private events ready — create one in the admin panel, then share the code.' as status;

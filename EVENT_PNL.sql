-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Event profit & loss
--
--  WHY: the expense tracker records what you SPEND. It has never
--  recorded what an event MADE, so the only way to know whether a
--  Saturday was worth doing has been to work it out in your head.
--
--  This stores one row per event: heads, price, the studio's share,
--  the goodie bags, and anything else that came out of it. The page
--  does the arithmetic — Stripe fees included — and keeps the history
--  so you can compare a reformer day against a mat day.
--
--  Owner-only, the same is_owner() login the expense tracker uses.
--  Nobody else can read or write it.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

--  Studios charge two different ways and the arithmetic isn't the same:
--  a revenue SHARE scales with how full the room is, a flat RENTAL is
--  owed whether two people turn up or fifteen. Both are stored, so an
--  event can use either — or a flat fee plus a share, which some deals
--  are. Safe to run again if you already ran an earlier version.

create table if not exists public.event_pnl (
  id             uuid primary key default gen_random_uuid(),
  event_name     text not null,
  event_date     date,
  people         integer not null default 0,
  price_each     numeric(10,2) not null default 0,
  studio_pct     numeric(5,2)  not null default 25,    -- your revenue share
  studio_on_net  boolean       not null default false, -- their % of gross, or of after-Stripe
  stripe_pct     numeric(5,3)  not null default 2.9,
  stripe_fixed   numeric(5,2)  not null default 0.30,
  bag_each       numeric(10,2) not null default 0,     -- goodie bag cost per head
  other_costs    numeric(12,2) not null default 0,     -- travel, product, printing…
  hours          numeric(6,2),                         -- optional: for $/hour
  notes          text,
  created_at     timestamptz   not null default now()
);

-- Added after the first version — these run harmlessly if they're there.
alter table public.event_pnl
  add column if not exists studio_flat numeric(12,2) not null default 0;
alter table public.event_pnl
  add column if not exists studio_mode text not null default 'share';   -- share | flat | both

alter table public.event_pnl enable row level security;

-- Owner only — read and write.
drop policy if exists event_pnl_owner_all on public.event_pnl;
create policy event_pnl_owner_all on public.event_pnl
  for all
  using (public.is_owner())
  with check (public.is_owner());

revoke all on table public.event_pnl from anon;
grant select, insert, update, delete on table public.event_pnl to authenticated;

-- ── Tying an expense to an event ────────────────────────────────────
--  An expense logged in the tracker below (the studio invoice, the
--  goodie bags, the parking) can now name the event it belongs to, and
--  the Profit & Loss panel subtracts it automatically. Without this the
--  same cost has to be typed twice — once as an expense and again into
--  the event's "everything else" box — and the two drift apart.
--
--  on delete set null: deleting an event must never delete the expense
--  record. It just stops being tied to anything.
alter table public.business_expenses
  add column if not exists event_id uuid references public.event_pnl(id) on delete set null;

create index if not exists business_expenses_event_idx
  on public.business_expenses (event_id);

select 'ready — Profit & Loss can save events, and expenses can be tied to them.' as status;

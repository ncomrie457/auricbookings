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

alter table public.event_pnl enable row level security;

-- Owner only — read and write.
drop policy if exists event_pnl_owner_all on public.event_pnl;
create policy event_pnl_owner_all on public.event_pnl
  for all
  using (public.is_owner())
  with check (public.is_owner());

revoke all on table public.event_pnl from anon;
grant select, insert, update, delete on table public.event_pnl to authenticated;

select 'ready — the Profit & Loss section on /expenses/ can now save events.' as status;

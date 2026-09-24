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

-- ── Tying an expense to the events it covered ───────────────────────
--  One purchase often covers several events: a bulk goodie-bag order, a
--  banner, a box of grip socks. So this is a join table, not a column —
--  an expense can name as many events as it actually paid for.
--
--  The expense record itself stays WHOLE. All $300 is still one
--  deductible purchase. The split below is only for working out what a
--  single Saturday really cost, and the shares always add back to the
--  full amount.
--
--  split_method, on the expense:
--    even     — $300 across 3 events is $100 each. Right for a banner or
--               a speaker, used regardless of how full the room was.
--    per_head — shared out by attendance. Right for anything consumed
--               per person: an event of 25 used more bags than one of 15.
--
--  on delete cascade: removing an event drops its links, never the
--  expense. The purchase stays in your books, tied to one fewer event.

create table if not exists public.expense_events (
  expense_id uuid not null references public.business_expenses(id) on delete cascade,
  event_id   uuid not null references public.event_pnl(id)         on delete cascade,
  primary key (expense_id, event_id)
);

create index if not exists expense_events_event_idx on public.expense_events (event_id);

alter table public.business_expenses
  add column if not exists split_method text not null default 'even';   -- even | per_head

alter table public.expense_events enable row level security;
drop policy if exists expense_events_owner_all on public.expense_events;
create policy expense_events_owner_all on public.expense_events
  for all using (public.is_owner()) with check (public.is_owner());

revoke all on table public.expense_events from anon;
grant select, insert, update, delete on table public.expense_events to authenticated;

-- Carry over anything tagged under the earlier one-event-per-expense
-- version, so nothing already recorded is lost. Wrapped in a check
-- because that column only exists if you ran the earlier version —
-- naming it unguarded would error for anyone who didn't.
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='business_expenses'
                and column_name='event_id') then
    insert into public.expense_events (expense_id, event_id)
      select id, event_id from public.business_expenses where event_id is not null
    on conflict do nothing;
    -- The join table is now the only place a link lives. Two sources
    -- would drift the moment either was edited.
    alter table public.business_expenses drop column event_id;
  end if;
end $$;

select 'ready — events save, and one expense can be split across the events it covered.' as status;

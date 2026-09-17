-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — monthly subscription rows (EmailJS + Anthropic Claude)
--
--  Creates one expense row per month for each subscription, so every
--  charge already has a line waiting for its receipt. Attach the receipt
--  in the tracker (Edit → Receipt) as each month's charge posts.
--
--  As set up below it creates, for Sep–Dec 2026:
--    · EmailJS            $20.66 / month
--    · Anthropic (Claude) $109.88 / month
--  Both dated the 1st. Change any of the five values in the "params" block
--  if the amounts, the billing day, or the months are different — e.g. set
--  first_month back to an earlier month if those months are missing too.
--
--  Safe to re-run: a vendor that already has a row in a given month is
--  skipped, so nothing gets doubled up.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

with params as (
  select
    date '2026-09-01' as first_month,      -- ← first month to create
    date '2026-12-01' as last_month,       -- ← last month to create
    1                 as bill_day,         -- ← day of month you're charged
    20.66::numeric    as emailjs_monthly,  -- ← EmailJS per month
    109.88::numeric   as claude_monthly    -- ← Claude subscription per month
),
months as (
  select generate_series(p.first_month, p.last_month, interval '1 month')::date as m, p.*
  from params p
),
planned as (
  select (m + (bill_day - 1))                             as spent_on,
         'EmailJS'                                        as vendor,
         emailjs_monthly                                  as amount,
         'Transactional email service — ' || to_char(m,'Mon YYYY') as purpose
  from months
  union all
  select (m + (bill_day - 1)),
         'Anthropic (Claude)',
         claude_monthly,
         'Claude subscription — ' || to_char(m,'Mon YYYY')
  from months
)
insert into public.business_expenses
  (spent_on, vendor, category, amount, payment_method, purpose, notes, deductible)
select pl.spent_on, pl.vendor, 'Software & Fees', pl.amount, 'Card', pl.purpose,
       'Recurring monthly subscription — add the receipt when the charge posts.', true
from planned pl
where not exists (
  select 1 from public.business_expenses e
  where e.vendor = pl.vendor
    and e.spent_on is not null
    and to_char(e.spent_on,'YYYY-MM') = to_char(pl.spent_on,'YYYY-MM')
);

-- What the two subscriptions look like now, month by month.
select to_char(spent_on,'YYYY-MM')   as month,
       vendor,
       amount,
       (receipt_path is not null)    as has_receipt
from public.business_expenses
where vendor in ('EmailJS','Anthropic (Claude)')
order by vendor, spent_on nulls first;

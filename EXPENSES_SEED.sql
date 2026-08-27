-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — seed the expense tracker with your existing expenses
--
--  Run this AFTER EXPENSES_SETUP.sql. It loads the 29 expenses you sent.
--  Dates you provided are filled in; the rest are left blank for you to
--  add later (edit the row in the tracker). A few category guesses are
--  noted — change any of them in the tracker if you'd like.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

insert into public.business_expenses
  (spent_on, vendor, category, amount, purpose) values
  ('2026-06-19', 'The Space',              'Venue / Studio Rental',        110.00, 'Studio rental — 1pm/2pm session'),
  ('2026-08-01', 'Fitin Studio',           'Venue / Studio Rental',        180.00, 'Studio rental — Mat & Chat, 11:30am'),
  (null,         'NY Business Express',     'Legal & Registration',          10.00, 'Articles of Organization'),
  (null,         'Anthropic (Claude API)',  'Software & Fees',                5.44, 'Claude API usage'),
  (null,         'Anthropic (Claude)',      'Software & Fees',              109.88, 'Claude subscription'),
  (null,         'Namecheap',               'Software & Fees',               11.48, 'Domain (auricmovement.com)'),
  (null,         'NY State',                'Legal & Registration',         200.00, 'LLC registration'),
  (null,         'EmailJS',                 'Software & Fees',               20.66, 'Transactional email service'),
  (null,         'Alibaba',                 'Merch & Supplies',             238.29, 'Custom bags for goodie bags (set 1)'),
  (null,         'Revel',                   'Merch & Supplies',             193.36, 'Grip socks for goodie bags'),
  (null,         'Bridge Tower Media',      'Marketing / Ads',               56.39, 'Publication'),
  (null,         'Newsday',                 'Marketing / Ads',              382.50, 'Advertising'),
  (null,         'Metropolis Technologies', 'Travel / Mileage',              42.70, 'Parking — The Space walkthrough'),
  (null,         'Alibaba',                 'Merch & Supplies',             239.20, 'Custom bags for goodie bags (set 2)'),
  (null,         'Temu',                    'Merch & Supplies',              68.00, 'Signage / raffle gifts'),
  (null,         null,                      'Merch & Supplies',               7.00, 'Scrunchies'),
  (null,         'OnBrand',                 'Merch & Supplies',              17.99, 'Donor gift bags'),
  (null,         'Fitin Studio',            'Venue / Studio Rental',        180.00, 'Studio rental'),
  ('2026-06-05', null,                      'Merch & Supplies',               7.99, 'Pens'),
  ('2026-06-05', null,                      'Merch & Supplies',               5.99, 'Gift tags'),
  ('2026-06-05', null,                      'Merch & Supplies',              18.99, 'Tote bags'),
  ('2026-06-05', null,                      'Merch & Supplies',               3.78, 'Gum (goodie bags)'),
  (null,         null,                      'Merch & Supplies',              25.00, 'Thank you cards'),
  (null,         'OnBrand',                 'Merch & Supplies',              17.99, 'Donor gifts — Mat & Chat'),
  (null,         'Alibaba',                 'Merch & Supplies',             143.25, 'AURIC MVMT bags'),
  (null,         'Amazon',                  'Merch & Supplies',              10.88, 'Scrunchies'),
  (null,         'Amazon',                  'Merch & Supplies',              16.32, 'Haitian/Jamaican flags (Riddim & Kompa)'),
  (null,         'Amazon',                  'Merch & Supplies',              43.54, 'Mooliwe affirmation cards for goodie bags'),
  ('2026-06-26', 'Amazon',                  'Equipment (Reformers, Props)',  29.99, 'Gliders (props)');

select count(*) as expenses_loaded, to_char(sum(amount),'FM999,999.00') as total_usd
from public.business_expenses;

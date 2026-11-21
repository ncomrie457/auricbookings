-- ════════════════════════════════════════════════════════════════════
--  Optional — a tidy column for the 2027 form's "reformer or mat?"
--
--  THE FORM WORKS WITHOUT THIS. If the column is missing it writes the
--  answer into the front of preferred_times instead ("Reformer only —
--  Weekend mornings"), the admin panel reads both shapes, and nothing is
--  lost. Run this only when you want the answer in its own CSV column.
--
--  Additive and safe to re-run: on a database that already has it this
--  does nothing. Existing rows read NULL, which is what they are — they
--  were never asked.
--
--  HOW TO RUN: Supabase → SQL Editor → paste → Run.
-- ════════════════════════════════════════════════════════════════════

alter table public.blooming_interest
  add column if not exists equipment text;

--  Read it back. Rows that answered before the column existed carry the
--  answer at the front of preferred_times; this is where you would see
--  them, and there is no need to tidy them up — the panel reads both.
select name, email, phone, equipment, preferred_times, created_at
from   public.blooming_interest
where  source = '2027-interest' or event = 'auric-2027'
order  by created_at;

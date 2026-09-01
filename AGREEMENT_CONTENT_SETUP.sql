-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — editable content for the /northwell agreement page
--
--  Stores the owner-edited "deal points" and "terms" HTML so you can edit
--  the agreement text right on the page and have Northwell see your version.
--  Anyone can READ the content (the page needs it to render); only the owner
--  (is_owner()) can INSERT/UPDATE it.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. One time.
-- ════════════════════════════════════════════════════════════════════

create table if not exists public.agreement_content (
  id         text primary key,     -- e.g. 'northwell'
  deal_html  text,
  terms_html text,
  updated_at timestamptz default now()
);

alter table public.agreement_content enable row level security;

-- Public can read the current content.
drop policy if exists ac_public_read on public.agreement_content;
create policy ac_public_read on public.agreement_content
  for select using (true);

-- Only the owner can create or edit it.
drop policy if exists ac_owner_write on public.agreement_content;
create policy ac_owner_write on public.agreement_content
  for all to authenticated
  using (public.is_owner()) with check (public.is_owner());

grant select on public.agreement_content to anon, authenticated;
grant insert, update on public.agreement_content to authenticated;

select 'agreement_content ready — you can now edit the /northwell terms in place.' as status;

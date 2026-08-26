-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Step 5: Collaborator login for the Something's
--  Blooming interest list (view + export ONLY, nothing else).
--
--  What this does:
--   • Adds a "blooming" role your admin_roles table already understands.
--   • Adds is_blooming_viewer() — true for the owner OR anyone seeded with
--     the 'blooming' role.
--   • Adds blooming_read() — a server function that returns ONLY the
--     Something's Blooming rows (no riddim, no bag pre-orders) and ONLY to
--     an owner or a blooming collaborator. Everyone else gets nothing.
--
--  The collaborator can SELECT this list and export it. They cannot read
--  the reformer / mat & chat / create & recharge rosters, cannot see
--  payments, and cannot delete or edit anything — those all stay behind
--  is_owner().
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

-- 1) Who counts as a Blooming viewer (owner is always allowed).
create or replace function public.is_blooming_viewer()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admin_roles
    where user_id = auth.uid() and role in ('owner','blooming')
  );
$$;

-- 2) The read function: only Blooming rows, only for owner/collaborator.
create or replace function public.blooming_read()
returns setof public.blooming_interest
language sql stable security definer set search_path = public as $$
  select *
  from public.blooming_interest
  where public.is_blooming_viewer()
    and coalesce(source,'') not in ('riddim-interest','bag-reserve')
    and coalesce(event,'')  not in ('riddim-kompa-next','auric-bag-reserve')
  order by created_at;
$$;

grant execute on function public.is_blooming_viewer() to anon, authenticated;
grant execute on function public.blooming_read()      to anon, authenticated;

select 'Step 5 functions created.' as status;

-- ────────────────────────────────────────────────────────────────────
--  AFTER you run the above:
--
--  A) Create the collaborator's login:
--     Supabase → Authentication → Users → Add user →
--       Email:    <your collaborator's email>
--       Password: <a password you share with them>
--       ✅ Auto Confirm User
--
--  B) Give that login the 'blooming' role (replace the email):
--
--     insert into public.admin_roles (user_id, role)
--     select id, 'blooming' from auth.users
--     where email = 'COLLABORATOR_EMAIL_HERE'
--     on conflict (user_id) do update set role = excluded.role;
--
--  C) Confirm it landed:
--     select u.email, a.role
--     from public.admin_roles a join auth.users u on u.id = a.user_id
--     order by a.role;
--
--  That's it — they log in at book.auricmovement.com/blooming-list with
--  that email + password and see only the Something's Blooming list.
-- ────────────────────────────────────────────────────────────────────

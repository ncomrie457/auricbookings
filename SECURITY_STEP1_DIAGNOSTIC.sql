-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — Security audit, STEP 1: READ-ONLY DIAGNOSTIC
--  Purpose: show the CURRENT state of Row-Level Security, policies,
--  and the booking/admin functions — so the real fix can be written
--  precisely without breaking public booking or signup forms.
--
--  ▶ This query CHANGES NOTHING. It only reads settings.
--
--  HOW TO RUN:
--   1. Supabase dashboard → your project → "SQL Editor" (left sidebar)
--   2. Click "New query", paste ALL of this, click "Run"
--   3. There are 4 result sets below (run each block, or run all and
--      use the tabs). Copy the output of each back to me.
-- ════════════════════════════════════════════════════════════════════

-- ── 1) Which tables exist, and is RLS turned ON for each? ────────────
--    (RLS OFF = the public key can do anything to that table.)
select
  n.nspname               as schema,
  c.relname               as table_name,
  c.relrowsecurity        as rls_enabled,
  c.relforcerowsecurity   as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relname;

-- ── 2) Every RLS policy: table, name, command, who it applies to ────
select
  schemaname,
  tablename,
  policyname,
  cmd            as command,          -- SELECT / INSERT / UPDATE / DELETE / ALL
  roles          as applies_to_roles, -- {anon}, {authenticated}, {public}, ...
  qual           as using_expression, -- row filter for read/update/delete
  with_check     as with_check_expression
from pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;

-- ── 3) The booking/admin functions and their security mode ──────────
select
  p.proname                                   as function_name,
  pg_get_function_identity_arguments(p.oid)   as arguments,
  case when p.prosecdef then 'SECURITY DEFINER' else 'security invoker' end as security_mode
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (p.proname like 'book_%' or p.proname like 'reformer_%')
order by p.proname;

-- ── 4) Who is allowed to EXECUTE each of those functions? ────────────
--    (Look for 'anon' — anon EXECUTE on an admin function = anyone can call it.)
select
  r.routine_name                    as function_name,
  g.grantee,
  g.privilege_type
from information_schema.routine_privileges g
join information_schema.routines r
  on r.specific_name = g.specific_name
where r.specific_schema = 'public'
  and (r.routine_name like 'book_%' or r.routine_name like 'reformer_%')
order by r.routine_name, g.grantee;

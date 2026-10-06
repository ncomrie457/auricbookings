-- ═══════════════════════════════════════════════════════════════════════════
--  Save admin panel settings to your account instead of to one browser.
--
--  WHY
--    The custom reminder settings — greeting, message, days, question box,
--    link — were kept in localStorage. That meant three things, all bad:
--
--      • They lived in one browser. Saved on the laptop, absent on the phone.
--      • Clearing Safari website data erased them, which is exactly what you
--        get told to do whenever a page looks stale.
--      • There was no record of them anywhere you could look.
--
--    This gives the panel a small key/value store on your account, so a
--    setting saved anywhere is a setting saved everywhere.
--
--  WHAT IT IS
--    One table and two functions. The table has no RLS policies at all, so
--    nothing can read or write it directly — everything goes through the two
--    functions, and both check is_owner() exactly like the reformer ones.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run. Safe to re-run.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.admin_settings (
  key        text primary key,
  value      jsonb       not null,
  updated_at timestamptz not null default now()
);

comment on table public.admin_settings is
  'Admin panel preferences, keyed by setting name (e.g. reminder_draft_reformer-o10). '
  'Owner-only, reached through admin_settings_get/set — never read directly.';

-- Locked by default. No policies are created on purpose: with RLS on and no
-- policy, anon and authenticated can do nothing here, and only the two
-- security-definer functions below can touch it.
alter table public.admin_settings enable row level security;

-- Read one setting. Returns null for anyone who is not the owner, rather than
-- raising — the panel treats "nothing saved" and "not allowed" the same way,
-- and falls back to the browser copy.
create or replace function public.admin_settings_get(k text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select case
           when public.is_owner()
           then (select value from public.admin_settings where key = k)
           else null
         end;
$$;

-- Write one setting. Raises for anyone who is not the owner, so a failed save
-- is loud — the panel says "saved on this device only" rather than pretending.
create or replace function public.admin_settings_set(k text, v jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_owner() then
    raise exception 'not authorized';
  end if;

  insert into public.admin_settings (key, value)
  values (k, v)
  on conflict (key) do update
    set value = excluded.value,
        updated_at = now();
end;
$$;

revoke all on function public.admin_settings_set(text, jsonb) from public, anon;
grant execute on function public.admin_settings_get(text)        to authenticated;
grant execute on function public.admin_settings_set(text, jsonb) to authenticated;

select 'admin_settings ready.' as status;

-- ─── Checks ──────────────────────────────────────────────────────────────

-- 1) Everything saved so far. Empty until you press "Save these settings"
--    once while signed in.
select key, updated_at, jsonb_pretty(value) as saved
from public.admin_settings
order by updated_at desc;

-- 2) Prove the lock works. Signed in as you this returns your row; the same
--    query from an unauthenticated session returns null.
select public.admin_settings_get('reminder_draft_reformer-o10') as oct10_settings;

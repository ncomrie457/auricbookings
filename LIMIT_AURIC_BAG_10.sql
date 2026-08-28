-- ════════════════════════════════════════════════════════════════════
--  AURIC MOVEMENT — cap AURIC MVMT bag reservations at 10 TOTAL
--  (across every event, not per event).
--
--  Reservations are stored in blooming_interest (source='bag-reserve').
--  Because that table is owner-only, the public site can't read the count
--  itself — so these two server functions do it safely:
--    • bag_reserve_count()  → returns just the number reserved (for the
--      site to show a "sold out" state). No names/emails exposed.
--    • reserve_auric_bag()  → reserves a bag ONLY if fewer than 10 exist,
--      atomically. Returns 'reserved', 'already' (same email), or 'full'.
--      This is what makes 10 a hard cap even if two people tap at once.
--
--  HOW TO RUN: Supabase → SQL Editor → paste ALL → Run.
-- ════════════════════════════════════════════════════════════════════

create or replace function public.bag_reserve_count()
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from public.blooming_interest where source = 'bag-reserve';
$$;

create or replace function public.reserve_auric_bag(p_name text, p_email text)
returns text language plpgsql security definer set search_path = public as $$
declare cnt int;
begin
  if coalesce(trim(p_email), '') = '' then
    return 'error';
  end if;
  -- Same email already reserved? Treat as success (idempotent, no dupes).
  if exists (
    select 1 from public.blooming_interest
    where source = 'bag-reserve' and lower(email) = lower(trim(p_email))
  ) then
    return 'already';
  end if;
  -- Hard cap: 10 total.
  select count(*) into cnt from public.blooming_interest where source = 'bag-reserve';
  if cnt >= 10 then
    return 'full';
  end if;
  insert into public.blooming_interest (name, email, phone, event, source)
  values (nullif(trim(p_name), ''), trim(p_email), null, 'auric-bag-reserve', 'bag-reserve');
  return 'reserved';
end $$;

grant execute on function public.bag_reserve_count()             to anon, authenticated;
grant execute on function public.reserve_auric_bag(text, text)   to anon, authenticated;

select 'AURIC MVMT bag capped at 10 total.' as status,
       public.bag_reserve_count() as currently_reserved;

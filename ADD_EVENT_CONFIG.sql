-- Stores per-event badge settings (collab, future badges).
-- Admin panel toggles read/write to this table.

create table if not exists public.event_config (
  event_id   text primary key,
  is_collab  boolean default false,
  updated_at timestamptz default now()
);

alter table public.event_config enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'event_config' and policyname = 'anon read') then
    execute 'create policy "anon read"   on public.event_config for select to anon using (true)';
  end if;
  if not exists (select 1 from pg_policies where tablename = 'event_config' and policyname = 'anon insert') then
    execute 'create policy "anon insert" on public.event_config for insert to anon with check (true)';
  end if;
  if not exists (select 1 from pg_policies where tablename = 'event_config' and policyname = 'anon update') then
    execute 'create policy "anon update" on public.event_config for update to anon using (true) with check (true)';
  end if;
end $$;

-- Seed defaults
insert into public.event_config (event_id) values ('pilates'), ('matchat')
on conflict (event_id) do nothing;

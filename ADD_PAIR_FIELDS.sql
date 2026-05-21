-- Adds friend fields to Mat & Chat for pair pricing
alter table public.matchat_registrations add column if not exists friend_name text;
alter table public.matchat_registrations add column if not exists friend_email text;
alter table public.matchat_registrations add column if not exists is_pair boolean default false;

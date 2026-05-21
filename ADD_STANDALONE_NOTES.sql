-- Add notes column to standalone_waivers for the health disclosure on waiver.auricmovement.com
alter table public.standalone_waivers add column if not exists notes text;

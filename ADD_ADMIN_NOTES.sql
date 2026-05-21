-- Adds an admin_notes column to each table for per-registrant notes
alter table public.pilates_registrations add column if not exists admin_notes text;
alter table public.matchat_registrations add column if not exists admin_notes text;
alter table public.corporate_inquiries  add column if not exists admin_notes text;
alter table public.corporate_bookings   add column if not exists admin_notes text;
alter table public.standalone_waivers   add column if not exists admin_notes text;

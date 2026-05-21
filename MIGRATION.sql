-- ===== Migration data: JSONBin → Supabase =====
-- Run this in Supabase → SQL Editor → New query → Run
-- This imports your 12 existing records (10 Pilates, 2 Notify) into the new tables.

insert into public.pilates_registrations (session_id,name,email,signature,session_label,arrival,class_start,type,wl_position,code,clauses_agreed,time_str,timestamp_iso) values
  ('s1','Yaffascha Jackson','Shilohcakes93@gmail.com','Yaffascha Jackson','Session 1','1:00 PM','1:05 PM','confirmed',NULL,'AUR-X3U2JO',19,'5/9/2026, 10:00:54 AM','2026-05-09T14:00:54.997Z'),
  ('s1','Donielle Capers','Shilohcakes93@gmail.com','Donielle Capers','Session 1','1:00 PM','1:05 PM','confirmed',NULL,'AUR-LR6ORR',19,'5/9/2026, 10:05:08 AM','2026-05-09T14:05:08.955Z'),
  ('s1','Rachel Joslyn','rachel.joslyn@aol.com',NULL,'Session 1','1:00 PM','1:05 PM','confirmed',NULL,'AUR-OAAGJ0',19,'5/11/2026, 10:31:55 PM','2026-05-12T02:31:55.049Z'),
  ('s1','Angelina Adam','angelinaesqny@gmail.com',NULL,'Session 1','1:00 PM','1:05 PM','confirmed',NULL,'AUR-BJEDYW',19,'5/11/2026, 10:32:14 PM','2026-05-12T02:32:14.631Z'),
  ('s1','Karleen Adam Comrie','karleenadamcomrie@outlook.com',NULL,'Session 1','1:00 PM','1:05 PM','confirmed',NULL,'AUR-P2EA2N',19,'5/11/2026, 10:32:30 PM','2026-05-12T02:32:30.800Z'),
  ('s1','Breana Owens','breana_owens@aol.com',NULL,'Session 1','1:00 PM','1:05 PM','confirmed',NULL,'AUR-36VAFZ',19,'5/11/2026, 10:32:49 PM','2026-05-12T02:32:49.501Z'),
  ('s2','Nadia Davis','clover1033@aol.com',NULL,'Session 2','2:00 PM','2:05 PM','confirmed',NULL,'AUR-MTR2XD',19,'5/11/2026, 10:33:14 PM','2026-05-12T02:33:14.949Z'),
  ('s2','Marina Diaz','mediaz204@gmail.com',NULL,'Session 2','2:00 PM','2:05 PM','confirmed',NULL,'AUR-4DO65N',19,'5/11/2026, 10:33:33 PM','2026-05-12T02:33:33.132Z'),
  ('s2','Samantha Napoleon','samantha.napoleon@gmail.com',NULL,'Session 2','2:00 PM','2:05 PM','confirmed',NULL,'AUR-MC1I43',19,'5/11/2026, 10:34:24 PM','2026-05-12T02:34:24.649Z'),
  ('s2','Geraldine Powell','gpow85@hotmail.com','Geraldine Powell','Session 2','2:00 PM','2:05 PM','confirmed',NULL,'AUR-635UJ1',19,'5/12/2026, 9:14:56 AM','2026-05-12T13:14:56.852Z');

insert into public.notify_list (name,email,time_str) values
  ('ni','hey1nini1home@gmail.com','5/9/2026, 8:29:10 AM'),
  ('Amber Nichole','amber.nichole27@icloud.com','5/10/2026, 7:14:15 AM');

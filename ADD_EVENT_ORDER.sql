-- Adds a sort_index column to event_config so the admin panel can set the
-- display order of events (drag-to-reorder). Lower sort_index shows first.
-- Run this once in the Supabase SQL editor.

alter table public.event_config add column if not exists sort_index int default 0;

-- V59.2 migration: link Casual Crew induction materials to existing Health & Safety content.
-- Run in Supabase SQL Editor after the original V59 setup SQL.
alter table public.regency_casual_hs_materials add column if not exists source_id text;
alter table public.regency_casual_hs_materials add column if not exists source_kind text;
create unique index if not exists regency_casual_hs_materials_source_id_uq
  on public.regency_casual_hs_materials(source_id) where source_id is not null;
-- Keep director-only write access from the original setup. Public RPCs continue to expose active material only.

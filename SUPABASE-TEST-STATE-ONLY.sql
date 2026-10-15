-- Regency Events V48: shared company state + Health & Safety storage
create extension if not exists pgcrypto;

create table if not exists public.regency_state (
  org_id text primary key,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

alter table public.regency_state enable row level security;

drop policy if exists "Regency authenticated read" on public.regency_state;
drop policy if exists "Regency authenticated insert" on public.regency_state;
drop policy if exists "Regency authenticated update" on public.regency_state;
drop policy if exists "authenticated users can read Regency state" on public.regency_state;
drop policy if exists "authenticated users can insert Regency state" on public.regency_state;
drop policy if exists "authenticated users can update Regency state" on public.regency_state;

create policy "Regency authenticated read" on public.regency_state
for select to authenticated using (true);
create policy "Regency authenticated insert" on public.regency_state
for insert to authenticated with check (true);
create policy "Regency authenticated update" on public.regency_state
for update to authenticated using (true) with check (true);

-- Required for automatic multi-device Realtime sync.
do $$
begin
  alter publication supabase_realtime add table public.regency_state;
exception when duplicate_object then null;
end $$;

insert into storage.buckets (id, name, public)
values ('regency-hs', 'regency-hs', false)
on conflict (id) do update set public=false;

drop policy if exists "Regency H&S read" on storage.objects;
drop policy if exists "Regency H&S insert" on storage.objects;
drop policy if exists "Regency H&S update" on storage.objects;
drop policy if exists "Regency H&S delete" on storage.objects;

create policy "Regency H&S read" on storage.objects
for select to authenticated using (bucket_id = 'regency-hs');
create policy "Regency H&S insert" on storage.objects
for insert to authenticated with check (bucket_id = 'regency-hs');
create policy "Regency H&S update" on storage.objects
for update to authenticated using (bucket_id = 'regency-hs') with check (bucket_id = 'regency-hs');
create policy "Regency H&S delete" on storage.objects
for delete to authenticated using (bucket_id = 'regency-hs');

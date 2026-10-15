-- Regency Events AV Tracker: secure Casual Crew induction
-- Run this entire script in Supabase SQL Editor for the existing Regency project.
-- Then add the Director's Supabase Auth user UUID to the director table as described in README-CASUAL-CREW.txt.

create extension if not exists pgcrypto;

create table if not exists public.regency_casual_hs_directors (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.regency_casual_hs_materials (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) between 1 and 180),
  material_type text not null check (material_type in ('document','video')),
  url text not null check (url ~ '^https://'),
  description text not null default '',
  version_label text not null default '1.0' check (length(trim(version_label)) between 1 and 40),
  active boolean not null default true,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.regency_casual_hs_submissions (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  email text not null check (length(trim(email)) between 3 and 254),
  phone text,
  role text not null check (length(trim(role)) between 1 and 120),
  acknowledgements jsonb not null default '[]'::jsonb,
  final_confirmed boolean not null default false check (final_confirmed),
  submitted_at timestamptz not null default now(),
  source text not null default 'casual-public-form'
);

alter table public.regency_casual_hs_directors enable row level security;
alter table public.regency_casual_hs_materials enable row level security;
alter table public.regency_casual_hs_submissions enable row level security;

-- Do not permit direct public table access. Director access is based on a Supabase Auth UUID.
revoke all on public.regency_casual_hs_directors from anon, authenticated;
revoke all on public.regency_casual_hs_materials from anon, authenticated;
revoke all on public.regency_casual_hs_submissions from anon, authenticated;
grant select, insert, update, delete on public.regency_casual_hs_materials to authenticated;
grant select on public.regency_casual_hs_submissions to authenticated;
grant select on public.regency_casual_hs_directors to authenticated;

 drop policy if exists casual_hs_directors_self_read on public.regency_casual_hs_directors;
create policy casual_hs_directors_self_read on public.regency_casual_hs_directors
  for select to authenticated using (user_id = auth.uid());

drop policy if exists casual_hs_materials_director_all on public.regency_casual_hs_materials;
create policy casual_hs_materials_director_all on public.regency_casual_hs_materials
  for all to authenticated using (exists(select 1 from public.regency_casual_hs_directors d where d.user_id = auth.uid()))
  with check (exists(select 1 from public.regency_casual_hs_directors d where d.user_id = auth.uid()));

drop policy if exists casual_hs_submissions_director_read on public.regency_casual_hs_submissions;
create policy casual_hs_submissions_director_read on public.regency_casual_hs_submissions
  for select to authenticated using (exists(select 1 from public.regency_casual_hs_directors d where d.user_id = auth.uid()));

create or replace function public.casual_hs_public_materials()
returns table(id uuid,title text,material_type text,url text,description text,version_label text,sort_order integer)
language sql stable security definer set search_path = public
as $$
  select m.id,m.title,m.material_type,m.url,m.description,m.version_label,m.sort_order
  from public.regency_casual_hs_materials m where m.active = true order by m.sort_order,m.created_at;
$$;
revoke all on function public.casual_hs_public_materials() from public;
grant execute on function public.casual_hs_public_materials() to anon, authenticated;

create or replace function public.casual_hs_induction_requirements(p_email text default null)
returns table(id uuid,title text,material_type text,url text,description text,version_label text,sort_order integer)
language sql stable security definer set search_path = public
as $$
  select m.id,m.title,m.material_type,m.url,m.description,m.version_label,m.sort_order
  from public.regency_casual_hs_materials m
  where m.active = true and (
    nullif(lower(trim(coalesce(p_email,''))),'') is null
    or not exists (
      select 1 from public.regency_casual_hs_submissions s
      cross join lateral jsonb_array_elements(s.acknowledgements) a
      where lower(s.email)=lower(trim(p_email))
        and (a->>'material_id')=m.id::text
        and (a->>'version_label')=m.version_label
    )
  )
  order by m.sort_order,m.created_at;
$$;
revoke all on function public.casual_hs_induction_requirements(text) from public;
grant execute on function public.casual_hs_induction_requirements(text) to anon, authenticated;

create or replace function public.submit_casual_hs_induction(p_submission jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_name text := trim(coalesce(p_submission->>'full_name',''));
  v_email text := lower(trim(coalesce(p_submission->>'email','')));
  v_phone text := nullif(trim(coalesce(p_submission->>'phone','')),'');
  v_role text := trim(coalesce(p_submission->>'role',''));
  v_ack jsonb := coalesce(p_submission->'acknowledgements','[]'::jsonb);
  v_current_count integer;
  v_confirmed_count integer;
  v_snapshot jsonb;
  v_id uuid;
begin
  if length(v_name) < 2 or length(v_name) > 120 then raise exception 'Please enter your full name.'; end if;
  if length(v_email) < 3 or length(v_email) > 254 or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Please enter a valid email address.'; end if;
  if length(v_role) < 1 or length(v_role) > 120 then raise exception 'Please select your work role.'; end if;
  if coalesce((p_submission->>'final_confirmed')::boolean,false) is not true then raise exception 'The final confirmation is required.'; end if;
  if jsonb_typeof(v_ack) <> 'array' then raise exception 'Invalid acknowledgements.'; end if;
  select count(*) into v_current_count from public.casual_hs_induction_requirements(v_email);
  select count(distinct a->>'material_id') into v_confirmed_count
    from jsonb_array_elements(v_ack) a
    where coalesce((a->>'acknowledged')::boolean,false) is true;
  if v_current_count = 0 then
    if v_confirmed_count > 0 then raise exception 'No updated induction items are currently required.'; end if;
  else
    if v_confirmed_count <> v_current_count then raise exception 'Please acknowledge every required item.'; end if;
    if exists (
      select 1 from public.casual_hs_induction_requirements(v_email) m
      where not exists(select 1 from jsonb_array_elements(v_ack) a where a->>'material_id'=m.id::text and coalesce((a->>'acknowledged')::boolean,false) is true)
    ) then raise exception 'Please acknowledge every current induction item.'; end if;
  end if;
  -- Server-authoritative version snapshot for only the outstanding items.
  select coalesce(jsonb_agg(jsonb_build_object(
    'material_id',m.id,'title',m.title,'material_type',m.material_type,'url',m.url,
    'version_label',m.version_label,'acknowledged',true,'acknowledged_at',now()
  ) order by m.sort_order),'[]'::jsonb) into v_snapshot
  from public.casual_hs_induction_requirements(v_email) m;
  insert into public.regency_casual_hs_submissions(full_name,email,phone,role,acknowledgements,final_confirmed)
  values(v_name,v_email,v_phone,v_role,v_snapshot,true) returning id into v_id;
  return jsonb_build_object('success',true,'submission_id',v_id,'submitted_at',now(),'items_completed',v_current_count);
end;
$$;
revoke all on function public.submit_casual_hs_induction(jsonb) from public;
grant execute on function public.submit_casual_hs_induction(jsonb) to anon, authenticated;

-- Regular crew document register (director-only), including expiry and prior versions.
create table if not exists public.regency_crew_documents (
  id uuid primary key default gen_random_uuid(),
  crew_user_id text not null,
  crew_name text not null,
  document_type text not null default 'General document',
  document_name text not null,
  storage_path text not null,
  expiry_date date,
  uploaded_at timestamptz not null default now(),
  uploaded_by uuid references auth.users(id),
  is_latest boolean not null default true
);
alter table public.regency_crew_documents enable row level security;
revoke all on public.regency_crew_documents from anon, authenticated;
grant select, insert, update on public.regency_crew_documents to authenticated;
drop policy if exists regency_crew_documents_director_all on public.regency_crew_documents;
create policy regency_crew_documents_director_all on public.regency_crew_documents
 for all to authenticated
 using (exists(select 1 from public.regency_casual_hs_directors d where d.user_id=auth.uid()))
 with check (exists(select 1 from public.regency_casual_hs_directors d where d.user_id=auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('regency-crew-docs','regency-crew-docs',false,20971520,array['application/pdf','image/jpeg','image/png','image/webp','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict(id) do update set public=false;
drop policy if exists regency_crew_docs_director_storage on storage.objects;
create policy regency_crew_docs_director_storage on storage.objects
 for all to authenticated
 using (bucket_id='regency-crew-docs' and exists(select 1 from public.regency_casual_hs_directors d where d.user_id=auth.uid()))
 with check (bucket_id='regency-crew-docs' and exists(select 1 from public.regency_casual_hs_directors d where d.user_id=auth.uid()));

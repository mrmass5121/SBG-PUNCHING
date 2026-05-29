create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'viewer' check (role in ('admin', 'standard', 'viewer')),
  created_at timestamptz not null default now()
);

alter table public.profiles
  drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check check (role in ('admin', 'standard', 'viewer'));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;
revoke execute on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select private.is_admin();
$$;
revoke execute on function public.is_admin() from public, anon, authenticated;

create or replace function private.can_upload_productions()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'standard')
  );
$$;
revoke execute on function private.can_upload_productions() from public, anon;
grant execute on function private.can_upload_productions() to authenticated;

create or replace function private.can_view_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('admin', 'standard')
  );
$$;
revoke execute on function private.can_view_admin() from public, anon;
grant execute on function private.can_view_admin() to authenticated;

create table if not exists public.productions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) <= 140),
  customer_name text check (char_length(customer_name) <= 140),
  category text not null check (char_length(category) <= 80),
  material text check (char_length(material) <= 80),
  thickness text check (char_length(thickness) <= 80),
  quantity integer not null default 1 check (quantity > 0),
  status text not null default 'Queued' check (status in ('Queued', 'In Progress', 'Completed', 'On Hold', 'Cancelled')),
  production_date date not null default current_date,
  description text not null check (char_length(description) <= 900),
  tags text[] not null default '{}',
  media jsonb not null default '[]'::jsonb,
  featured boolean not null default false,
  is_public boolean not null default true,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.productions
  add column if not exists thickness text check (char_length(thickness) <= 80);

alter table public.productions
  add column if not exists quantity integer not null default 1;

alter table public.productions
  drop constraint if exists productions_quantity_check;

alter table public.productions
  add constraint productions_quantity_check check (quantity > 0);

alter table public.productions
  drop constraint if exists productions_status_check;

alter table public.productions
  add constraint productions_status_check
  check (status in ('Queued', 'In Progress', 'Completed', 'On Hold', 'Cancelled'));

create table if not exists public.inquiries (
  id uuid primary key default gen_random_uuid(),
  company_name text check (char_length(company_name) <= 140),
  contact_name text not null check (char_length(contact_name) <= 140),
  phone text not null check (char_length(phone) <= 40),
  email text check (char_length(email) <= 180),
  service text not null check (char_length(service) <= 120),
  message text not null check (char_length(message) <= 1200),
  source text not null default 'website',
  status text not null default 'New' check (status in ('New', 'Contacted', 'Quoted', 'Closed')),
  created_at timestamptz not null default now()
);


create or replace function public.limit_inquiry_rate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from public.inquiries
    where phone = new.phone
      and created_at > now() - interval '10 minutes'
  ) then
    raise exception 'Please wait before submitting another inquiry.';
  end if;
  return new;
end;
$$;

drop trigger if exists inquiries_limit_rate on public.inquiries;
create trigger inquiries_limit_rate
before insert on public.inquiries
for each row execute function public.limit_inquiry_rate();
create table if not exists public.service_notes (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) <= 140),
  category text not null check (char_length(category) <= 80),
  description text not null check (char_length(description) <= 700),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.production_reviews (
  id uuid primary key default gen_random_uuid(),
  product_slug text not null check (char_length(product_slug) between 3 and 140),
  rating integer not null check (rating between 1 and 5),
  reviewer_name text not null check (char_length(reviewer_name) between 2 and 80),
  comment text not null check (char_length(comment) between 3 and 700),
  approved boolean not null default false,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.production_reviews
  add column if not exists approved boolean not null default false;

alter table public.production_reviews
  add column if not exists reviewed_by uuid references auth.users(id);

alter table public.production_reviews
  add column if not exists reviewed_at timestamptz;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists productions_touch_updated_at on public.productions;
create trigger productions_touch_updated_at
before update on public.productions
for each row execute function public.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.productions enable row level security;
alter table public.inquiries enable row level security;
alter table public.service_notes enable row level security;
alter table public.production_reviews enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant select on public.profiles to authenticated;
grant select on public.productions to anon, authenticated;
grant insert, update, delete on public.productions to authenticated;
grant insert on public.inquiries to anon, authenticated;
grant insert on public.inquiries to service_role;
grant select, update, delete on public.inquiries to authenticated;
grant select on public.service_notes to anon, authenticated;
grant insert, update, delete on public.service_notes to authenticated;
grant select on public.production_reviews to anon, authenticated;
grant insert, update, delete on public.production_reviews to authenticated;
grant insert on public.production_reviews to service_role;

drop policy if exists "profiles own read" on public.profiles;
create policy "profiles own read" on public.profiles
for select to authenticated
using (id = auth.uid());

drop policy if exists "admins manage profiles" on public.profiles;
create policy "admins manage profiles" on public.profiles
for all to authenticated
using (private.is_admin())
with check (private.is_admin());

drop policy if exists "public read published productions" on public.productions;
create policy "public read published productions" on public.productions
for select to anon, authenticated
using (is_public = true);

drop policy if exists "admins read all productions" on public.productions;
drop policy if exists "admins and standard users read all productions" on public.productions;
create policy "admins and standard users read all productions" on public.productions
for select to authenticated
using (private.can_view_admin());

drop policy if exists "admins insert productions" on public.productions;
drop policy if exists "admins and standard users insert productions" on public.productions;
create policy "admins and standard users insert productions" on public.productions
for insert to authenticated
with check (private.can_upload_productions() and coalesce(created_by, auth.uid()) = auth.uid());

drop policy if exists "admins update productions" on public.productions;
create policy "admins update productions" on public.productions
for update to authenticated
using (private.is_admin())
with check (private.is_admin());

drop policy if exists "admins delete productions" on public.productions;
create policy "admins delete productions" on public.productions
for delete to authenticated
using (private.is_admin());

drop policy if exists "public insert inquiries" on public.inquiries;
create policy "public insert inquiries" on public.inquiries
for insert to authenticated
with check (
  private.is_admin()
  and
  char_length(contact_name) between 2 and 140
  and char_length(phone) between 7 and 40
  and char_length(message) between 5 and 1200
);

drop policy if exists "admins manage inquiries" on public.inquiries;
create policy "admins manage inquiries" on public.inquiries
for all to authenticated
using (private.is_admin())
with check (private.is_admin());

drop policy if exists "admins and standard users read inquiries" on public.inquiries;
create policy "admins and standard users read inquiries" on public.inquiries
for select to authenticated
using (private.can_view_admin());

drop policy if exists "public read service notes" on public.service_notes;
create policy "public read service notes" on public.service_notes
for select to anon, authenticated
using (true);

drop policy if exists "admins manage service notes" on public.service_notes;
create policy "admins manage service notes" on public.service_notes
for all to authenticated
using (private.is_admin())
with check (private.is_admin());

drop policy if exists "public read production reviews" on public.production_reviews;
create policy "public read production reviews" on public.production_reviews
for select to anon, authenticated
using (approved = true);

drop policy if exists "public insert production reviews" on public.production_reviews;
create policy "public insert production reviews" on public.production_reviews
for insert to authenticated
with check (
  private.is_admin()
  and char_length(product_slug) between 3 and 140
  and rating between 1 and 5
  and char_length(reviewer_name) between 2 and 80
  and char_length(comment) between 3 and 700
  and approved = false
);

drop policy if exists "admins read production reviews" on public.production_reviews;
drop policy if exists "admins and standard users read production reviews" on public.production_reviews;
create policy "admins and standard users read production reviews" on public.production_reviews
for select to authenticated
using (private.can_view_admin());

drop policy if exists "admins update production reviews" on public.production_reviews;
create policy "admins update production reviews" on public.production_reviews
for update to authenticated
using (private.is_admin())
with check (private.is_admin());

drop policy if exists "admins delete production reviews" on public.production_reviews;
create policy "admins delete production reviews" on public.production_reviews
for delete to authenticated
using (private.is_admin());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'production-media-public',
    'production-media-public',
    true,
    20971520,
    array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']
  ),
  (
    'production-media-private',
    'production-media-private',
    false,
    20971520,
    array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']
  )
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

update storage.buckets
set public = false
where id = 'production-media';

drop policy if exists "public read production media" on storage.objects;
drop policy if exists "public read public production media" on storage.objects;
drop policy if exists "admins read production media" on storage.objects;
drop policy if exists "admins and standard users read production media" on storage.objects;
create policy "public read public production media" on storage.objects
for select
using (bucket_id = 'production-media-public');

create policy "admins and standard users read production media" on storage.objects
for select to authenticated
using (bucket_id in ('production-media-public', 'production-media-private') and private.can_view_admin());

drop policy if exists "admins upload production media" on storage.objects;
drop policy if exists "admins and standard users upload production media" on storage.objects;
create policy "admins and standard users upload production media" on storage.objects
for insert to authenticated
with check (
  bucket_id in ('production-media-public', 'production-media-private')
  and (
    private.is_admin()
    or (
      private.can_upload_productions()
      and (storage.foldername(name))[1] = auth.uid()::text
    )
  )
);

drop policy if exists "admins update production media" on storage.objects;
create policy "admins update production media" on storage.objects
for update to authenticated
using (bucket_id in ('production-media-public', 'production-media-private') and private.is_admin())
with check (bucket_id in ('production-media-public', 'production-media-private') and private.is_admin());

drop policy if exists "admins delete production media" on storage.objects;
create policy "admins delete production media" on storage.objects
for delete to authenticated
using (bucket_id in ('production-media-public', 'production-media-private') and private.is_admin());

create index if not exists productions_public_date_idx on public.productions (is_public, production_date desc, created_at desc);
create index if not exists productions_category_idx on public.productions (category);
create index if not exists inquiries_created_idx on public.inquiries (created_at desc);
create index if not exists production_reviews_slug_created_idx on public.production_reviews (product_slug, created_at desc);

do $$
begin
  alter publication supabase_realtime add table public.productions;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.production_reviews;
exception
  when duplicate_object then null;
end $$;


revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.limit_inquiry_rate() from public, anon, authenticated;
revoke execute on function public.touch_updated_at() from public, anon, authenticated;

do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end $$;
notify pgrst, 'reload schema';







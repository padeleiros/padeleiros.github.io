-- Bandeja padel shop: database for listings from other sellers.
-- Run this once in your Supabase project: SQL Editor -> New query -> paste -> Run.

-- 1. Listings table
create table if not exists public.listings (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  name         text not null check (char_length(name) between 3 and 80),
  condition    text not null check (condition in ('New','Like new','Very good','Good','Fair')),
  price        numeric(7,2) not null check (price > 0 and price < 5000),
  shape        text check (shape in ('round','teardrop','diamond')),
  weight       text check (char_length(weight) <= 20),
  notes        text check (char_length(notes) <= 600),
  review       text check (review is null or review ~ '^https://(www\.|m\.)?(youtube\.com|youtu\.be)/'),
  photos       text[] not null default '{}' check (coalesce(array_length(photos, 1), 0) <= 4),
  seller_name  text not null check (char_length(seller_name) between 2 and 40),
  seller_phone text not null check (seller_phone ~ '^9[1236][0-9]{7}$'),
  manage_code  text not null default encode(extensions.gen_random_bytes(5), 'hex')
);

alter table public.listings enable row level security;

-- Everyone can read listings, but never the secret manage_code.
drop policy if exists "Anyone can read listings" on public.listings;
create policy "Anyone can read listings" on public.listings
  for select to anon, authenticated using (true);

revoke all on public.listings from anon, authenticated;
grant select (id, created_at, name, condition, price, shape, weight, notes, review, photos, seller_name, seller_phone)
  on public.listings to anon, authenticated;

-- 2. Creating a listing goes through this function, which returns the seller's secret code.
create or replace function public.create_listing(
  p_name text, p_condition text, p_price numeric, p_shape text, p_weight text,
  p_notes text, p_review text, p_photos text[], p_seller_name text, p_seller_phone text
) returns json
language plpgsql security definer set search_path = public
as $$
declare
  r public.listings;
  ph text;
begin
  foreach ph in array coalesce(p_photos, '{}') loop
    if ph !~ '^[a-z0-9-]+\.jpg$' then
      raise exception 'Invalid photo name';
    end if;
  end loop;
  insert into public.listings (name, condition, price, shape, weight, notes, review, photos, seller_name, seller_phone)
  values (trim(p_name), p_condition, p_price, nullif(p_shape, ''), nullif(trim(p_weight), ''),
          nullif(trim(p_notes), ''), nullif(trim(p_review), ''), coalesce(p_photos, '{}'),
          trim(p_seller_name), p_seller_phone)
  returning * into r;
  return json_build_object('id', r.id, 'manage_code', r.manage_code);
end;
$$;

-- 3. Sellers remove their own listing with the secret code.
create or replace function public.delete_listing(p_id uuid, p_code text) returns boolean
language plpgsql security definer set search_path = public
as $$
begin
  delete from public.listings where id = p_id and manage_code = lower(trim(p_code));
  return found;
end;
$$;

revoke all on function public.create_listing(text,text,numeric,text,text,text,text,text[],text,text) from public;
revoke all on function public.delete_listing(uuid,text) from public;
grant execute on function public.create_listing(text,text,numeric,text,text,text,text,text[],text,text) to anon, authenticated;
grant execute on function public.delete_listing(uuid,text) to anon, authenticated;

-- 4. Photo storage: public bucket, JPEG only, max 3 MB per photo.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 3145728, array['image/jpeg'])
on conflict (id) do nothing;

drop policy if exists "Anyone can upload racket photos" on storage.objects;
create policy "Anyone can upload racket photos" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'photos');

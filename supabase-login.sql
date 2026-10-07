-- Bandeja: listings belong to signed-in accounts (Google login).
-- Run once, after supabase-setup.sql: SQL Editor -> New query -> paste -> Run.

alter table public.listings
  add column if not exists user_id uuid not null default auth.uid() references auth.users(id) on delete cascade;
alter table public.listings drop column if exists manage_code;
create index if not exists listings_user_id_idx on public.listings(user_id);

drop function if exists public.delete_listing(uuid, text);
drop function if exists public.create_listing(text,text,numeric,text,text,text,text,text[],text,text);

revoke all on public.listings from anon, authenticated;
grant select (id, created_at, name, condition, price, shape, weight, notes, review, photos, seller_name, seller_phone, user_id)
  on public.listings to anon, authenticated;
grant insert (name, condition, price, shape, weight, notes, review, photos, seller_name, seller_phone)
  on public.listings to authenticated;
grant delete on public.listings to authenticated;

drop policy if exists "Signed-in users add their own listings" on public.listings;
create policy "Signed-in users add their own listings" on public.listings
  for insert to authenticated with check (user_id = (select auth.uid()));

drop policy if exists "Owners remove their own listings" on public.listings;
create policy "Owners remove their own listings" on public.listings
  for delete to authenticated using (user_id = (select auth.uid()));

-- Creates a listing for the signed-in user; photos must be in their own folder.
create or replace function public.create_listing(
  p_name text, p_condition text, p_price numeric, p_shape text, p_weight text,
  p_notes text, p_review text, p_photos text[], p_seller_name text, p_seller_phone text
) returns uuid
language plpgsql security invoker set search_path = public
as $$
declare
  new_id uuid;
  ph text;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Sign in to list a racket';
  end if;
  foreach ph in array coalesce(p_photos, '{}') loop
    if ph !~ ('^' || uid::text || '/[a-z0-9-]+\.jpg$') then
      raise exception 'Invalid photo name';
    end if;
  end loop;
  insert into public.listings (name, condition, price, shape, weight, notes, review, photos, seller_name, seller_phone)
  values (trim(p_name), p_condition, p_price, nullif(p_shape, ''), nullif(trim(p_weight), ''),
          nullif(trim(p_notes), ''), nullif(trim(p_review), ''), coalesce(p_photos, '{}'),
          trim(p_seller_name), p_seller_phone)
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.create_listing(text,text,numeric,text,text,text,text,text[],text,text) from public, anon;
grant execute on function public.create_listing(text,text,numeric,text,text,text,text,text[],text,text) to authenticated;

-- Photos: only signed-in users, only inside a folder named after their account.
drop policy if exists "Anyone can upload racket photos" on storage.objects;
drop policy if exists "Users upload photos to their folder" on storage.objects;
drop policy if exists "Users see their own photos" on storage.objects;
drop policy if exists "Users delete their own photos" on storage.objects;
create policy "Users upload photos to their folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Users see their own photos" on storage.objects
  for select to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Users delete their own photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

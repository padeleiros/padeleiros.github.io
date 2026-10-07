-- Bandeja: public profiles (username + optional name), sold listings and reviews.
-- Run once, after supabase-login.sql: SQL Editor -> New query -> paste -> Run.

-- 1. Profiles -------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  username   text not null unique check (username ~ '^[a-z0-9_.]{3,20}$'),
  full_name  text check (full_name is null or char_length(full_name) between 1 and 60),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

revoke all on public.profiles from anon, authenticated;
grant select (id, username, full_name, created_at) on public.profiles to anon, authenticated;
grant insert (id, username, full_name) on public.profiles to authenticated;
grant update (username, full_name) on public.profiles to authenticated;

drop policy if exists "Anyone can see profiles" on public.profiles;
create policy "Anyone can see profiles" on public.profiles for select to anon, authenticated using (true);
drop policy if exists "Users create their own profile" on public.profiles;
create policy "Users create their own profile" on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
drop policy if exists "Users edit their own profile" on public.profiles;
create policy "Users edit their own profile" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- People who already signed in get a temporary username they can change.
insert into public.profiles (id, username)
select u.id, 'jogador_' || left(replace(u.id::text, '-', ''), 8)
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict do nothing;

-- 2. Listings point to profiles, and can be marked as sold ----------------
alter table public.listings drop constraint if exists listings_user_id_fkey;
alter table public.listings
  add constraint listings_user_id_fkey foreign key (user_id) references public.profiles(id) on delete cascade;

alter table public.listings add column if not exists sold_at  timestamptz;
alter table public.listings add column if not exists buyer_id uuid references public.profiles(id) on delete set null;
create index if not exists listings_buyer_id_idx on public.listings(buyer_id);

grant select (sold_at, buyer_id) on public.listings to anon, authenticated;
grant update (sold_at, buyer_id) on public.listings to authenticated;

drop policy if exists "Owners mark their listings as sold" on public.listings;
create policy "Owners mark their listings as sold" on public.listings for update to authenticated
  using (user_id = (select auth.uid()) and sold_at is null)
  with check (user_id = (select auth.uid()) and sold_at is not null
              and buyer_id is not null and buyer_id <> (select auth.uid()));

-- Sold listings stay, so their reviews stay visible.
drop policy if exists "Owners remove their own listings" on public.listings;
create policy "Owners remove their own listings" on public.listings for delete to authenticated
  using (user_id = (select auth.uid()) and sold_at is null);

-- 3. Creating a listing now takes the seller's name from their profile -----
drop function if exists public.create_listing(text,text,numeric,text,text,text,text,text[],text,text);
create or replace function public.create_listing(
  p_name text, p_condition text, p_price numeric, p_shape text, p_weight text,
  p_notes text, p_review text, p_photos text[], p_seller_phone text
) returns uuid
language plpgsql security invoker set search_path = public
as $$
declare
  new_id uuid;
  ph text;
  uid uuid := auth.uid();
  seller text;
begin
  if uid is null then
    raise exception 'Sign in to list a racket';
  end if;
  select coalesce(full_name, username) into seller from public.profiles where id = uid;
  if seller is null then
    raise exception 'Choose a username first';
  end if;
  foreach ph in array coalesce(p_photos, '{}') loop
    if ph !~ ('^' || uid::text || '/[a-z0-9-]+\.jpg$') then
      raise exception 'Invalid photo name';
    end if;
  end loop;
  insert into public.listings (name, condition, price, shape, weight, notes, review, photos, seller_name, seller_phone)
  values (trim(p_name), p_condition, p_price, nullif(p_shape, ''), nullif(trim(p_weight), ''),
          nullif(trim(p_notes), ''), nullif(trim(p_review), ''), coalesce(p_photos, '{}'),
          left(seller, 40), p_seller_phone)
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.create_listing(text,text,numeric,text,text,text,text,text[],text) from public, anon;
grant execute on function public.create_listing(text,text,numeric,text,text,text,text,text[],text) to authenticated;

-- seller_name was typed by the seller; profiles are now the source, so allow short usernames too.
alter table public.listings drop constraint if exists listings_seller_name_check;
alter table public.listings add constraint listings_seller_name_check check (char_length(seller_name) between 1 and 60);

-- 4. Reviews: one per sale, written only by the confirmed buyer -------------
create table if not exists public.reviews (
  id         uuid primary key default gen_random_uuid(),
  listing_id uuid not null unique references public.listings(id) on delete cascade,
  seller_id  uuid not null references public.profiles(id) on delete cascade,
  buyer_id   uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  rating     int  not null check (rating between 1 and 5),
  comment    text check (comment is null or char_length(comment) <= 500),
  created_at timestamptz not null default now()
);
create index if not exists reviews_seller_id_idx on public.reviews(seller_id);
alter table public.reviews enable row level security;

revoke all on public.reviews from anon, authenticated;
grant select on public.reviews to anon, authenticated;
grant insert (listing_id, seller_id, rating, comment) on public.reviews to authenticated;
grant update (rating, comment) on public.reviews to authenticated;

drop policy if exists "Anyone can read reviews" on public.reviews;
create policy "Anyone can read reviews" on public.reviews for select to anon, authenticated using (true);

drop policy if exists "Buyers review their purchase" on public.reviews;
create policy "Buyers review their purchase" on public.reviews for insert to authenticated
  with check (
    buyer_id = (select auth.uid())
    and exists (
      select 1 from public.listings l
      where l.id = listing_id and l.sold_at is not null
        and l.buyer_id = (select auth.uid()) and l.user_id = seller_id
    )
  );

drop policy if exists "Buyers edit their review" on public.reviews;
create policy "Buyers edit their review" on public.reviews for update to authenticated
  using (buyer_id = (select auth.uid())) with check (buyer_id = (select auth.uid()));

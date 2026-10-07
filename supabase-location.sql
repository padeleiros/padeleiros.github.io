-- Padeleiros: location on listings (region + optional town).
-- Run once, after supabase-profiles.sql: SQL Editor -> New query -> paste -> Run.

alter table public.listings add column if not exists location text
  check (location is null or char_length(location) between 2 and 40);
alter table public.listings add column if not exists town text
  check (town is null or char_length(town) between 1 and 60);
create index if not exists listings_location_idx on public.listings(location);

grant select (location, town) on public.listings to anon, authenticated;

drop function if exists public.create_listing(text,text,numeric,text,text,text,text,text[],text);
create or replace function public.create_listing(
  p_name text, p_condition text, p_price numeric, p_shape text, p_weight text,
  p_notes text, p_review text, p_photos text[], p_seller_phone text,
  p_location text, p_town text
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
  if coalesce(trim(p_location), '') = '' then
    raise exception 'Choose a location';
  end if;
  foreach ph in array coalesce(p_photos, '{}') loop
    if ph !~ ('^' || uid::text || '/[a-z0-9-]+\.jpg$') then
      raise exception 'Invalid photo name';
    end if;
  end loop;
  insert into public.listings (name, condition, price, shape, weight, notes, review, photos,
                               seller_name, seller_phone, location, town)
  values (trim(p_name), p_condition, p_price, nullif(p_shape, ''), nullif(trim(p_weight), ''),
          nullif(trim(p_notes), ''), nullif(trim(p_review), ''), coalesce(p_photos, '{}'),
          left(seller, 40), p_seller_phone, trim(p_location), nullif(trim(p_town), ''))
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.create_listing(text,text,numeric,text,text,text,text,text[],text,text,text) from public, anon;
grant execute on function public.create_listing(text,text,numeric,text,text,text,text,text[],text,text,text) to authenticated;

grant insert (location, town) on public.listings to authenticated;

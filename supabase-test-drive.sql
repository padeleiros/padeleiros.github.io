-- Padeleiros: optional "can be tested before buying" on listings.
-- Run once, after supabase-sold-optional.sql: SQL Editor -> New query -> paste -> Run.

alter table public.listings add column if not exists can_test boolean not null default false;
grant select (can_test) on public.listings to anon, authenticated;
grant insert (can_test), update (can_test) on public.listings to authenticated;

-- create_listing / update_listing gain an optional p_can_test (defaults to false,
-- so older versions of the site keep working).
drop function if exists public.create_listing(text,text,numeric,text,text,text,text,text[],text,text,text);
create or replace function public.create_listing(
  p_name text, p_condition text, p_price numeric, p_shape text, p_weight text,
  p_notes text, p_review text, p_photos text[], p_seller_phone text,
  p_location text, p_town text, p_can_test boolean default false
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
                               seller_name, seller_phone, location, town, can_test)
  values (trim(p_name), p_condition, p_price, nullif(p_shape, ''), nullif(trim(p_weight), ''),
          nullif(trim(p_notes), ''), nullif(trim(p_review), ''), coalesce(p_photos, '{}'),
          left(seller, 40), p_seller_phone, trim(p_location), nullif(trim(p_town), ''),
          coalesce(p_can_test, false))
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.create_listing(text,text,numeric,text,text,text,text,text[],text,text,text,boolean) from public, anon;
grant execute on function public.create_listing(text,text,numeric,text,text,text,text,text[],text,text,text,boolean) to authenticated;

drop function if exists public.update_listing(uuid,text,text,numeric,text,text,text,text,text[],text,text,text);
create or replace function public.update_listing(
  p_id uuid, p_name text, p_condition text, p_price numeric, p_shape text, p_weight text,
  p_notes text, p_review text, p_photos text[], p_seller_phone text,
  p_location text, p_town text, p_can_test boolean default false
) returns boolean
language plpgsql security invoker set search_path = public
as $$
declare
  ph text;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Sign in to edit a listing';
  end if;
  if coalesce(trim(p_location), '') = '' then
    raise exception 'Choose a location';
  end if;
  if coalesce(array_length(p_photos, 1), 0) = 0 then
    raise exception 'Add at least one photo';
  end if;
  foreach ph in array p_photos loop
    if ph !~ ('^' || uid::text || '/[a-z0-9-]+\.jpg$') and ph !~ '^[a-z0-9-]+\.jpg$' then
      raise exception 'Invalid photo name';
    end if;
  end loop;
  update public.listings set
    name = trim(p_name), condition = p_condition, price = p_price, shape = nullif(p_shape, ''),
    weight = nullif(trim(p_weight), ''), notes = nullif(trim(p_notes), ''), review = nullif(trim(p_review), ''),
    photos = p_photos, seller_phone = p_seller_phone, location = trim(p_location), town = nullif(trim(p_town), ''),
    can_test = coalesce(p_can_test, false)
  where id = p_id and user_id = uid and sold_at is null;
  return found;
end;
$$;
revoke all on function public.update_listing(uuid,text,text,numeric,text,text,text,text,text[],text,text,text,boolean) from public, anon;
grant execute on function public.update_listing(uuid,text,text,numeric,text,text,text,text,text[],text,text,text,boolean) to authenticated;

-- Padeleiros: sellers can edit their listings while they are not sold.
-- Run once, after supabase-location.sql: SQL Editor -> New query -> paste -> Run.

grant update (name, condition, price, shape, weight, notes, review, photos, seller_phone, location, town)
  on public.listings to authenticated;

drop policy if exists "Owners edit their unsold listings" on public.listings;
create policy "Owners edit their unsold listings" on public.listings for update to authenticated
  using (user_id = (select auth.uid()) and sold_at is null)
  with check (user_id = (select auth.uid()) and sold_at is null);

create or replace function public.update_listing(
  p_id uuid, p_name text, p_condition text, p_price numeric, p_shape text, p_weight text,
  p_notes text, p_review text, p_photos text[], p_seller_phone text,
  p_location text, p_town text
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
    -- new photos are in the seller's folder; older listings may keep photos without a folder
    if ph !~ ('^' || uid::text || '/[a-z0-9-]+\.jpg$') and ph !~ '^[a-z0-9-]+\.jpg$' then
      raise exception 'Invalid photo name';
    end if;
  end loop;
  update public.listings set
    name = trim(p_name), condition = p_condition, price = p_price, shape = nullif(p_shape, ''),
    weight = nullif(trim(p_weight), ''), notes = nullif(trim(p_notes), ''), review = nullif(trim(p_review), ''),
    photos = p_photos, seller_phone = p_seller_phone, location = trim(p_location), town = nullif(trim(p_town), '')
  where id = p_id and user_id = uid and sold_at is null;
  return found;
end;
$$;
revoke all on function public.update_listing(uuid,text,text,numeric,text,text,text,text,text[],text,text,text) from public, anon;
grant execute on function public.update_listing(uuid,text,text,numeric,text,text,text,text,text[],text,text,text) to authenticated;

-- Padeleiros: marking a listing as sold no longer requires naming the buyer.
-- Without a buyer the sale simply can't be reviewed.
-- Run once, after supabase-edit.sql: SQL Editor -> New query -> paste -> Run.

drop policy if exists "Owners mark their listings as sold" on public.listings;
create policy "Owners mark their listings as sold" on public.listings for update to authenticated
  using (user_id = (select auth.uid()) and sold_at is null)
  with check (user_id = (select auth.uid()) and sold_at is not null
              and (buyer_id is null or buyer_id <> (select auth.uid())));

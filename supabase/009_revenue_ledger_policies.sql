-- Revenue ledger access rules. Apply after 008_notifications_realtime.sql.

drop policy if exists "creators read own revenue ledger" on public.revenue_ledger;
create policy "creators read own revenue ledger" on public.revenue_ledger
for select
using (creator_id = auth.uid() or public.current_user_is_admin());

drop policy if exists "admins manage revenue ledger" on public.revenue_ledger;
create policy "admins manage revenue ledger" on public.revenue_ledger
for all
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

-- Admin moderation queue and post enforcement. Apply after 011_profile_privacy_visibility.sql.
create policy "admins read reports" on public.reports for select
using (public.current_user_is_admin());

create policy "admins update reports" on public.reports for update
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

create policy "admins moderate posts" on public.posts for update
using (public.current_user_is_admin())
with check (public.current_user_is_admin());

create policy "admins read admin actions" on public.admin_actions for select
using (public.current_user_is_admin());

create policy "admins create admin actions" on public.admin_actions for insert
with check (admin_id = auth.uid() and public.current_user_is_admin());

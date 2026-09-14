-- Authentication profile bootstrap and private media storage foundation.
-- Apply after 006_creator_analytics.sql.

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'username', ''), 'user_' || substr(replace(new.id::text, '-', ''), 1, 12)),
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute function public.handle_new_user_profile();

insert into storage.buckets (id, name, public)
values ('mesee-media', 'mesee-media', false)
on conflict (id) do update set public = excluded.public;

drop policy if exists "users upload own media" on storage.objects;
create policy "users upload own media" on storage.objects
for insert to authenticated
with check (bucket_id = 'mesee-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "users read own media" on storage.objects;
create policy "users read own media" on storage.objects
for select to authenticated
using (bucket_id = 'mesee-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "users update own media" on storage.objects;
create policy "users update own media" on storage.objects
for update to authenticated
using (bucket_id = 'mesee-media' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'mesee-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "users delete own media" on storage.objects;
create policy "users delete own media" on storage.objects
for delete to authenticated
using (bucket_id = 'mesee-media' and (storage.foldername(name))[1] = auth.uid()::text);

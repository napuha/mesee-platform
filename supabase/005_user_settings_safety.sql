-- User settings and safety preferences. Apply after 004_privacy_blocks.sql.

alter table public.profiles add column if not exists birth_date date;
alter table public.profiles add column if not exists safety_review_status text not null default 'unreviewed'
  check (safety_review_status in ('unreviewed','clear','restricted','suspended'));

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  account_visibility public.visibility not null default 'public',
  notify_likes boolean not null default true,
  notify_saves boolean not null default true,
  notify_followers boolean not null default true,
  notify_reposts boolean not null default true,
  notify_messages boolean not null default true,
  theme text not null default 'system' check (theme in ('light','dark','system','combo')),
  updated_at timestamptz not null default now()
);

alter table public.user_settings enable row level security;

create policy "users read own settings" on public.user_settings for select
using (user_id = auth.uid());
create policy "users create own settings" on public.user_settings for insert
with check (user_id = auth.uid());
create policy "users update own settings" on public.user_settings for update
using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.ensure_default_user_settings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_settings(user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists profile_default_settings on public.profiles;
create trigger profile_default_settings
after insert on public.profiles
for each row execute function public.ensure_default_user_settings();

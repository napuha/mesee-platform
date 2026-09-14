-- Privacy, blocking, and notification controls. Apply after 003_counters_notifications.sql.

create table if not exists public.blocked_users (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocked_users enable row level security;

create policy "users create own profile" on public.profiles for insert
with check (id = auth.uid());
create policy "users delete own profile" on public.profiles for delete
using (id = auth.uid());

create policy "users read public audio" on public.audio_tracks for select
using (rights_status = 'approved' or owner_id = auth.uid());
create policy "users create own audio" on public.audio_tracks for insert
with check (owner_id = auth.uid());

create policy "users mark own notifications read" on public.notifications for update
using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "users manage own blocks" on public.blocked_users for all
using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy "users see blocks involving self" on public.blocked_users for select
using (blocker_id = auth.uid());

create or replace function public.can_view_post(target_post uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.posts p
    where p.id = target_post
      and p.deleted_at is null
      and p.status = 'ready'
      and (
        ((p.visibility = 'public' or (p.visibility = 'followers' and exists (
          select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = p.author_id
        ))) and not exists (
          select 1 from public.blocked_users b
          where b.blocker_id = auth.uid() and b.blocked_id = p.author_id
        ))
        or p.author_id = auth.uid()
        or public.current_user_is_admin()
      )
  );
$$;

drop policy if exists "public posts are readable" on public.posts;
create policy "public posts are readable" on public.posts for select
using (public.can_view_post(id));

-- MeSee runtime entities and hardened access rules.
-- Apply after 001_initial_schema.sql.

alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.posts add column if not exists updated_at timestamptz not null default now();

create table if not exists public.post_view_events (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  viewer_id uuid references public.profiles(id) on delete set null,
  session_id text,
  event_type text not null check (event_type in ('impression','view_start','view_complete','skip')),
  watch_ms integer not null default 0 check (watch_ms >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create table if not exists public.admin_actions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles(id) on delete restrict,
  post_id uuid references public.posts(id) on delete set null,
  report_id uuid references public.reports(id) on delete set null,
  action text not null check (action in ('remove_post','restore_post','dismiss_report','block_user')),
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.creator_subscriptions (
  id uuid primary key default gen_random_uuid(),
  subscriber_id uuid not null references public.profiles(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null,
  provider_subscription_id text not null unique,
  status text not null check (status in ('trialing','active','past_due','canceled','ended')),
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  check (subscriber_id <> creator_id)
);

create index if not exists posts_feed_idx on public.posts (visibility, status, published_at desc);
create index if not exists post_view_events_post_idx on public.post_view_events (post_id, created_at desc);
create index if not exists messages_participants_idx on public.messages (sender_id, recipient_id, created_at desc);
create index if not exists reports_queue_idx on public.reports (status, created_at desc);

alter table public.post_view_events enable row level security;
alter table public.messages enable row level security;
alter table public.admin_actions enable row level security;
alter table public.creator_subscriptions enable row level security;

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$ select exists (select 1 from public.profiles where id = auth.uid() and is_admin = true) $$;

drop policy if exists "public posts are readable" on public.posts;
create policy "public posts are readable" on public.posts for select
using ((visibility = 'public' and status = 'ready' and deleted_at is null)
  or author_id = auth.uid()
  or public.current_user_is_admin());

create policy "users create view events" on public.post_view_events for insert
with check (viewer_id is null or viewer_id = auth.uid());
create policy "users read own view events" on public.post_view_events for select
using (viewer_id = auth.uid() or public.current_user_is_admin());

create policy "participants read messages" on public.messages for select
using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy "users send messages" on public.messages for insert
with check (sender_id = auth.uid());
create policy "recipients mark messages read" on public.messages for update
using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

create policy "users create reports" on public.reports for insert
with check (reporter_id = auth.uid());
create policy "users read own reports" on public.reports for select
using (reporter_id = auth.uid() or public.current_user_is_admin());
create policy "admins manage reports" on public.reports for update
using (public.current_user_is_admin()) with check (public.current_user_is_admin());

create policy "admins read actions" on public.admin_actions for select
using (public.current_user_is_admin());
create policy "admins create actions" on public.admin_actions for insert
with check (admin_id = auth.uid() and public.current_user_is_admin());

create policy "users manage own subscriptions" on public.creator_subscriptions for select
using (subscriber_id = auth.uid() or creator_id = auth.uid());

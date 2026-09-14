create extension if not exists "pgcrypto";

create type public.post_kind as enum ('photo','vertical_video','horizontal_video','text','live');
create type public.visibility as enum ('public','private','followers');
create type public.media_status as enum ('draft','processing','ready','failed','deleted');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  display_name text not null default '',
  bio text not null default '',
  avatar_url text,
  header_url text,
  is_private boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  kind public.post_kind not null,
  title text not null default '',
  body text not null default '',
  visibility public.visibility not null default 'public',
  status public.media_status not null default 'draft',
  media_url text,
  thumbnail_url text,
  duration_ms integer,
  view_count bigint not null default 0,
  like_count bigint not null default 0,
  save_count bigint not null default 0,
  repost_count bigint not null default 0,
  impression_count bigint not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.post_reactions (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (reaction in ('like','save','repost')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, reaction)
);

create table public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table public.audio_tracks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  title text not null,
  audio_url text not null,
  usage_count bigint not null default 0,
  rights_status text not null default 'pending',
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  kind text not null,
  post_id uuid references public.posts(id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete cascade,
  reason text not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table public.revenue_ledger (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid references public.posts(id) on delete set null,
  gross_amount numeric(12,2) not null default 0,
  platform_fee numeric(12,2) not null default 0,
  creator_amount numeric(12,2) not null default 0,
  currency text not null default 'JPY',
  period_start date not null,
  period_end date not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_reactions enable row level security;
alter table public.follows enable row level security;
alter table public.audio_tracks enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;
alter table public.revenue_ledger enable row level security;

create policy "public profiles are readable" on public.profiles for select using (not is_private or id = auth.uid());
create policy "users edit own profile" on public.profiles for update using (id = auth.uid());
create policy "public posts are readable" on public.posts for select using (visibility = 'public' and status = 'ready' or author_id = auth.uid());
create policy "users create own posts" on public.posts for insert with check (author_id = auth.uid());
create policy "users edit own posts" on public.posts for update using (author_id = auth.uid());
create policy "users react to posts" on public.post_reactions for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "users manage own follows" on public.follows for all using (follower_id = auth.uid()) with check (follower_id = auth.uid());
create policy "users read own notifications" on public.notifications for select using (user_id = auth.uid());

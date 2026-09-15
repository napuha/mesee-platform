-- Realtime comments for live broadcasts.
-- Apply after 018_messages_realtime.sql.

create table if not exists public.live_comments (
  id uuid primary key default gen_random_uuid(),
  live_post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists live_comments_post_idx on public.live_comments (live_post_id, created_at asc);
alter table public.live_comments enable row level security;

create policy "viewers read live comments" on public.live_comments for select
using (exists (
  select 1 from public.posts p
  where p.id = live_post_id
    and p.kind = 'live'
    and p.status <> 'deleted'
    and (p.visibility = 'public' or p.author_id = auth.uid())
));

create policy "authenticated users send live comments" on public.live_comments for insert
with check (author_id = auth.uid());

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'live_comments'
     ) then
    alter publication supabase_realtime add table public.live_comments;
  end if;
end;
$$;

alter table public.live_comments replica identity full;

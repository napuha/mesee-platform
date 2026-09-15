-- Profile counters used by the profile header.
create or replace function public.get_profile_stats(target_profile uuid default auth.uid())
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'following_count', (select count(*) from public.follows where follower_id = target_profile),
    'follower_count', (select count(*) from public.follows where following_id = target_profile),
    'like_count', coalesce((select sum(like_count) from public.posts where author_id = target_profile and status <> 'deleted'), 0),
    'post_count', (select count(*) from public.posts where author_id = target_profile and status <> 'deleted')
  );
$$;

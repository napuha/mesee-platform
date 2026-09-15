-- Personalize the first-party feed from a user's view and reaction history.
-- Apply after 013_account_deletion.sql.
create or replace function public.get_recommended_posts(result_limit integer default 20)
returns table (
  id uuid,
  author_id uuid,
  author_handle text,
  caption text,
  media_type text,
  view_count bigint,
  like_count bigint,
  media_url text,
  recommendation_score numeric
)
language sql
stable
security invoker
set search_path = public
as $$
  select p.id,
         p.author_id,
         pr.username as author_handle,
         coalesce(nullif(p.body, ''), p.title) as caption,
         case p.kind when 'vertical_video' then 'video_vertical' when 'horizontal_video' then 'video_horizontal' else p.kind::text end as media_type,
         p.view_count,
         p.like_count,
         p.media_url,
         (case when exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid() and f.following_id = p.author_id
          ) then 100 else 0 end
          + least(p.like_count, 100000)::numeric / 1000
          + least(p.view_count, 1000000)::numeric / 100000
          + greatest(0, 24 - extract(epoch from (now() - coalesce(p.published_at, p.created_at))) / 3600) / 24
          + coalesce((select count(*)::numeric * 8
                      from public.post_view_events v
                      join public.posts seen on seen.id = v.post_id
                      where v.viewer_id = auth.uid()
                        and v.event_type in ('view_start', 'view_complete')
                        and seen.kind = p.kind), 0)
          + coalesce((select count(*)::numeric * 12
                      from public.post_reactions r
                      join public.posts reacted on reacted.id = r.post_id
                      where r.user_id = auth.uid()
                        and r.reaction in ('like', 'save')
                        and reacted.kind = p.kind), 0)
          - coalesce((select count(*)::numeric * 10
                      from public.post_view_events skipped
                      join public.posts skipped_post on skipped_post.id = skipped.post_id
                      where skipped.viewer_id = auth.uid()
                        and skipped.event_type = 'skip'
                        and skipped_post.kind = p.kind), 0)
         ) as recommendation_score
  from public.posts p
  join public.profiles pr on pr.id = p.author_id
  where public.can_view_post(p.id)
  order by recommendation_score desc, p.published_at desc nulls last
  limit greatest(1, least(result_limit, 100));
$$;

-- Enforce private-profile visibility at the database boundary.
create or replace function public.can_view_post(target_post uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.posts p
    join public.profiles author on author.id = p.author_id
    where p.id = target_post
      and p.deleted_at is null
      and p.status = 'ready'
      and (
        (
          (p.visibility = 'public' or p.visibility = 'followers')
          and (not author.is_private or exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid() and f.following_id = p.author_id
          ))
          and (p.visibility = 'public' or exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid() and f.following_id = p.author_id
          ))
          and not exists (
            select 1 from public.blocked_users b
            where b.blocker_id = auth.uid() and b.blocked_id = p.author_id
          )
        )
        or p.author_id = auth.uid()
        or public.current_user_is_admin()
      )
  );
$$;

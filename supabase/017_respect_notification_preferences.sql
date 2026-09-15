-- Respect per-user notification switches in server-side notification triggers.
create or replace function public.record_post_reaction_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target_author uuid; enabled boolean;
begin
  if tg_op = 'INSERT' then
    select author_id into target_author from public.posts where id = new.post_id;
    select case new.reaction
      when 'like' then notify_likes
      when 'save' then notify_saves
      when 'repost' then notify_reposts
      else false end
      into enabled
      from public.user_settings where user_id = target_author;
    if target_author is not null and target_author <> new.user_id and coalesce(enabled, true) then
      insert into public.notifications(user_id, actor_id, kind, post_id)
      values (target_author, new.user_id, new.reaction, new.post_id);
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.record_follow_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare enabled boolean;
begin
  select notify_followers into enabled from public.user_settings where user_id = new.following_id;
  if coalesce(enabled, true) then
    insert into public.notifications(user_id, actor_id, kind)
    values (new.following_id, new.follower_id, 'follow');
  end if;
  return new;
end;
$$;

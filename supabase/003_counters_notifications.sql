-- Server-side counters and notifications. Apply after 002_social_runtime.sql.

create or replace function public.refresh_post_reaction_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_post uuid := coalesce(new.post_id, old.post_id);
begin
  update public.posts p
  set like_count = (select count(*) from public.post_reactions r where r.post_id = target_post and r.reaction = 'like'),
      save_count = (select count(*) from public.post_reactions r where r.post_id = target_post and r.reaction = 'save'),
      repost_count = (select count(*) from public.post_reactions r where r.post_id = target_post and r.reaction = 'repost'),
      updated_at = now()
  where p.id = target_post;
  return coalesce(new, old);
end;
$$;

drop trigger if exists post_reaction_counts on public.post_reactions;
create trigger post_reaction_counts
after insert or update or delete on public.post_reactions
for each row execute function public.refresh_post_reaction_count();

create or replace function public.record_post_reaction_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target_author uuid;
begin
  if tg_op = 'INSERT' then
    select author_id into target_author from public.posts where id = new.post_id;
    if target_author is not null and target_author <> new.user_id then
      insert into public.notifications(user_id, actor_id, kind, post_id)
      values (target_author, new.user_id, new.reaction, new.post_id);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists post_reaction_notifications on public.post_reactions;
create trigger post_reaction_notifications
after insert on public.post_reactions
for each row execute function public.record_post_reaction_notification();

create or replace function public.record_follow_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications(user_id, actor_id, kind)
  values (new.following_id, new.follower_id, 'follow');
  return new;
end;
$$;

drop trigger if exists follow_notifications on public.follows;
create trigger follow_notifications
after insert on public.follows
for each row execute function public.record_follow_notification();

create or replace function public.record_post_view_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.posts
  set impression_count = impression_count + case when new.event_type = 'impression' then 1 else 0 end,
      view_count = view_count + case when new.event_type = 'view_complete' then 1 else 0 end,
      updated_at = now()
  where id = new.post_id;
  return new;
end;
$$;

drop trigger if exists post_view_counters on public.post_view_events;
create trigger post_view_counters
after insert on public.post_view_events
for each row execute function public.record_post_view_event();

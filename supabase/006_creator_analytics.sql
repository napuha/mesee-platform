-- Creator analytics and revenue calculation RPC. Apply after 005_user_settings_safety.sql.

create table if not exists public.revenue_rates (
  id uuid primary key default gen_random_uuid(),
  platform_fee_rate numeric(5,4) not null check (platform_fee_rate >= 0 and platform_fee_rate <= 1),
  effective_from timestamptz not null default now(),
  effective_until timestamptz
);

insert into public.revenue_rates(platform_fee_rate)
select 0.2000
where not exists (select 1 from public.revenue_rates);

alter table public.revenue_rates enable row level security;

create or replace function public.get_creator_analytics(target_creator uuid)
returns table (
  total_posts bigint,
  total_views bigint,
  total_impressions bigint,
  total_likes bigint,
  total_saves bigint,
  total_reposts bigint,
  gross_revenue numeric,
  platform_fee numeric,
  creator_revenue numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  fee_rate numeric := coalesce((select r.platform_fee_rate from public.revenue_rates r
    where r.effective_from <= now() and (r.effective_until is null or r.effective_until > now())
    order by r.effective_from desc limit 1), 0.2);
begin
  if auth.uid() <> target_creator and not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;
  return query
  select count(*)::bigint,
    coalesce(sum(p.view_count),0)::bigint,
    coalesce(sum(p.impression_count),0)::bigint,
    coalesce(sum(p.like_count),0)::bigint,
    coalesce(sum(p.save_count),0)::bigint,
    coalesce(sum(p.repost_count),0)::bigint,
    coalesce(sum(p.impression_count),0)::numeric * 0.08,
    coalesce(sum(p.impression_count),0)::numeric * 0.08 * fee_rate,
    coalesce(sum(p.impression_count),0)::numeric * 0.08 * (1 - fee_rate)
  from public.posts p
  where p.author_id = target_creator and p.deleted_at is null;
end;
$$;

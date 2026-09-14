-- Account deletion request foundation. Apply after 012_admin_moderation_policies.sql.
create table if not exists public.account_deletion_requests (
  user_id uuid primary key references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null default (now() + interval '30 days'),
  canceled_at timestamptz,
  status text not null default 'pending' check (status in ('pending','canceled','completed'))
);

alter table public.account_deletion_requests enable row level security;

drop policy if exists "users read own deletion request" on public.account_deletion_requests;
create policy "users read own deletion request" on public.account_deletion_requests
  for select using (user_id = auth.uid());

drop policy if exists "users create own deletion request" on public.account_deletion_requests;
create policy "users create own deletion request" on public.account_deletion_requests
  for insert with check (user_id = auth.uid());

drop policy if exists "users cancel own deletion request" on public.account_deletion_requests;
create policy "users cancel own deletion request" on public.account_deletion_requests
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.request_account_deletion()
returns public.account_deletion_requests
language plpgsql
security invoker
set search_path = public
as $$
declare result public.account_deletion_requests;
begin
  insert into public.account_deletion_requests(user_id)
  values (auth.uid())
  on conflict (user_id) do update
    set requested_at = now(), scheduled_for = now() + interval '30 days', canceled_at = null, status = 'pending'
  returning * into result;
  return result;
end;
$$;

create or replace function public.cancel_account_deletion()
returns public.account_deletion_requests
language plpgsql
security invoker
set search_path = public
as $$
declare result public.account_deletion_requests;
begin
  update public.account_deletion_requests
    set canceled_at = now(), status = 'canceled'
    where user_id = auth.uid() and status = 'pending'
    returning * into result;
  return result;
end;
$$;

begin;

-- One atomic 24-hour reservation per user prevents bursts of newly created
-- places from producing a separate push for every matching place.
create table if not exists public.new_place_push_cooldowns (
  user_id uuid primary key references auth.users(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  reserved_at timestamptz not null default now()
);

alter table public.new_place_push_cooldowns enable row level security;
revoke all on table public.new_place_push_cooldowns from public, anon, authenticated;
grant select, insert, update, delete on table public.new_place_push_cooldowns
  to service_role;

create or replace function public.reserve_new_place_pushes(
  p_user_ids uuid[], p_place_id uuid
)
returns table(user_id uuid)
language sql
security invoker
set search_path = ''
as $$
  insert into public.new_place_push_cooldowns (user_id, place_id, reserved_at)
  select distinct recipients.user_id, p_place_id, now()
  from unnest(p_user_ids) as recipients(user_id)
  where recipients.user_id is not null
  on conflict (user_id) do update
    set place_id = excluded.place_id,
        reserved_at = excluded.reserved_at
    where new_place_push_cooldowns.reserved_at <= now() - interval '24 hours'
  returning new_place_push_cooldowns.user_id;
$$;

revoke all on function public.reserve_new_place_pushes(uuid[], uuid)
  from public, anon, authenticated;
grant execute on function public.reserve_new_place_pushes(uuid[], uuid)
  to service_role;

commit;

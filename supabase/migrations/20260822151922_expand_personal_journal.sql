
alter table public.visits
  add column if not exists with_whom text;

alter table public.visits
  add column if not exists journal_note text;

alter table public.visits
  add column if not exists favorite_memory boolean not null default false;

create table if not exists public.journal_collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text,
  cover_image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists journal_collections_user_id_idx
  on public.journal_collections(user_id);

alter table public.journal_collections enable row level security;

drop policy if exists "Users can read own journal collections"
on public.journal_collections;

create policy "Users can read own journal collections"
on public.journal_collections
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can create own journal collections"
on public.journal_collections;

create policy "Users can create own journal collections"
on public.journal_collections
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own journal collections"
on public.journal_collections;

create policy "Users can update own journal collections"
on public.journal_collections
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own journal collections"
on public.journal_collections;

create policy "Users can delete own journal collections"
on public.journal_collections
for delete
to authenticated
using ((select auth.uid()) = user_id);

grant select, insert, update, delete
on public.journal_collections
to authenticated;

create table if not exists public.journal_collection_visits (
  collection_id uuid not null references public.journal_collections(id) on delete cascade,
  visit_id uuid not null references public.visits(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (collection_id, visit_id)
);

create index if not exists journal_collection_visits_visit_id_idx
  on public.journal_collection_visits(visit_id);

alter table public.journal_collection_visits enable row level security;

drop policy if exists "Users can read own journal collection visits"
on public.journal_collection_visits;

create policy "Users can read own journal collection visits"
on public.journal_collection_visits
for select
to authenticated
using (
  exists (
    select 1
    from public.journal_collections c
    where c.id = collection_id
      and c.user_id = (select auth.uid())
  )
);

drop policy if exists "Users can create own journal collection visits"
on public.journal_collection_visits;

create policy "Users can create own journal collection visits"
on public.journal_collection_visits
for insert
to authenticated
with check (
  exists (
    select 1
    from public.journal_collections c
    where c.id = collection_id
      and c.user_id = (select auth.uid())
  )
  and exists (
    select 1
    from public.visits v
    where v.id = visit_id
      and v.user_id = (select auth.uid())
  )
);

drop policy if exists "Users can delete own journal collection visits"
on public.journal_collection_visits;

create policy "Users can delete own journal collection visits"
on public.journal_collection_visits
for delete
to authenticated
using (
  exists (
    select 1
    from public.journal_collections c
    where c.id = collection_id
      and c.user_id = (select auth.uid())
  )
);

grant select, insert, delete
on public.journal_collection_visits
to authenticated;

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  visit_id uuid references public.visits(id) on delete set null,
  title text,
  content text,
  entry_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  image_url text,
  with_whom text,
  tags text[]
);

create index if not exists journal_entries_user_id_idx
  on public.journal_entries(user_id);

create index if not exists journal_entries_entry_date_idx
  on public.journal_entries(user_id, entry_date desc);

create index if not exists journal_entries_visit_id_idx
  on public.journal_entries(visit_id);

alter table public.journal_entries enable row level security;

drop policy if exists "Users can read own journal entries"
on public.journal_entries;

create policy "Users can read own journal entries"
on public.journal_entries
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can create own journal entries"
on public.journal_entries;

create policy "Users can create own journal entries"
on public.journal_entries
for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own journal entries"
on public.journal_entries;

create policy "Users can update own journal entries"
on public.journal_entries
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own journal entries"
on public.journal_entries;

create policy "Users can delete own journal entries"
on public.journal_entries
for delete
to authenticated
using ((select auth.uid()) = user_id);

grant select, insert, update, delete
on public.journal_entries
to authenticated;

create index if not exists visits_user_visit_date_idx
  on public.visits(user_id, visit_date desc);

create index if not exists visits_user_place_idx
  on public.visits(user_id, place_id);

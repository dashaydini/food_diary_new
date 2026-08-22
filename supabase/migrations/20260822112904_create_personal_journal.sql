create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  visit_id uuid references public.visits(id) on delete set null,

  title text,
  content text,

  entry_date date not null default current_date,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index journal_entries_user_id_idx
  on public.journal_entries(user_id);

create index journal_entries_entry_date_idx
  on public.journal_entries(user_id, entry_date desc);

create index journal_entries_visit_id_idx
  on public.journal_entries(visit_id);

alter table public.journal_entries enable row level security;

create policy "Users can read own journal entries"
on public.journal_entries
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "Users can create own journal entries"
on public.journal_entries
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "Users can update own journal entries"
on public.journal_entries
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Users can delete own journal entries"
on public.journal_entries
for delete
to authenticated
using ((select auth.uid()) = user_id);

grant select, insert, update, delete
on public.journal_entries
to authenticated;

grant all
on public.journal_entries
to service_role;

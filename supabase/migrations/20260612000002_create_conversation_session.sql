create table if not exists public.conversation_session (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  source_type text not null,
  source_code text not null,
  status text not null default 'active',
  turn_count integer not null default 0,
  duration_seconds integer not null default 0,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists conversation_session_user_id_idx on public.conversation_session (user_id);
create index if not exists conversation_session_started_at_idx on public.conversation_session (started_at desc);
create index if not exists conversation_session_status_idx on public.conversation_session (status);

alter table public.conversation_session enable row level security;

drop policy if exists "conversation_session_select_own" on public.conversation_session;
create policy "conversation_session_select_own"
on public.conversation_session
for select
using (auth.uid() = user_id);


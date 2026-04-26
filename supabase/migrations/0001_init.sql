-- ============================================================
-- Job Tracker (Bewerbungen) — schema, RLS, triggers, storage.
-- All tables prefixed with jt_ to share project with other apps.
-- ============================================================

-- ---- profiles ----
create table if not exists public.jt_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  role text not null default 'user' check (role in ('user','admin')),
  created_at timestamptz not null default now()
);

-- ---- bewerbungen ----
create table if not exists public.jt_bewerbungen (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  job_title text not null,
  company text not null,
  location text default '',
  platform text default '',
  job_url text default '',
  applied_at date,
  status text not null default 'beworben',
  salary text default '',
  contact_person text default '',
  contact_email text default '',
  requirements text default '',
  notes text default '',
  starred boolean not null default false,
  interview_date timestamptz,
  interview_notes text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists jt_bewerbungen_user_id_idx on public.jt_bewerbungen(user_id);
create index if not exists jt_bewerbungen_status_idx on public.jt_bewerbungen(status);

-- ---- files ----
create table if not exists public.jt_files (
  id uuid primary key default gen_random_uuid(),
  bewerbung_id uuid not null references public.jt_bewerbungen(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  name text not null,
  mime text default '',
  size bigint default 0,
  kind text not null default 'other' check (kind in ('cv','motivation','other')),
  uploaded_at timestamptz not null default now()
);
create index if not exists jt_files_bewerbung_idx on public.jt_files(bewerbung_id);

-- ---- timeline ----
create table if not exists public.jt_timeline (
  id uuid primary key default gen_random_uuid(),
  bewerbung_id uuid not null references public.jt_bewerbungen(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_at timestamptz not null default now(),
  event_type text not null default 'note' check (event_type in ('note','status')),
  status text,
  note text default ''
);
create index if not exists jt_timeline_bewerbung_idx on public.jt_timeline(bewerbung_id);

-- ============================================================
-- helper: is current user admin?
-- ============================================================
create or replace function public.jt_is_admin()
returns boolean
language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.jt_profiles where id = auth.uid() and role = 'admin');
$fn$;

-- Public RPC: returns true only when no admin exists yet (first-run setup screen).
-- Callable by anon so the auth screen can decide which form to show.
create or replace function public.jt_setup_needed()
returns boolean
language sql stable security definer set search_path = public as $fn$
  select not exists (select 1 from public.jt_profiles where role = 'admin');
$fn$;
grant execute on function public.jt_setup_needed() to anon, authenticated;

-- ============================================================
-- auto-create profile; first user becomes admin
-- ============================================================
create or replace function public.jt_handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_count int;
  v_username text;
begin
  select count(*) into v_count from public.jt_profiles;
  v_username := coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1));
  if exists (select 1 from public.jt_profiles where username = v_username) then
    v_username := v_username || '_' || substring(new.id::text, 1, 4);
  end if;
  insert into public.jt_profiles (id, username, role)
  values (new.id, v_username, case when v_count = 0 then 'admin' else 'user' end)
  on conflict (id) do nothing;
  return new;
end;
$fn$;

drop trigger if exists jt_on_auth_user_created on auth.users;
create trigger jt_on_auth_user_created
  after insert on auth.users
  for each row execute function public.jt_handle_new_user();

-- updated_at trigger
create or replace function public.jt_touch_updated_at()
returns trigger language plpgsql as $fn$ begin new.updated_at = now(); return new; end; $fn$;

drop trigger if exists jt_bewerbungen_updated_at on public.jt_bewerbungen;
create trigger jt_bewerbungen_updated_at
  before update on public.jt_bewerbungen
  for each row execute function public.jt_touch_updated_at();

-- ============================================================
-- RLS
-- ============================================================
alter table public.jt_profiles    enable row level security;
alter table public.jt_bewerbungen enable row level security;
alter table public.jt_files       enable row level security;
alter table public.jt_timeline    enable row level security;

drop policy if exists jt_profiles_select on public.jt_profiles;
create policy jt_profiles_select on public.jt_profiles
  for select to authenticated
  using (id = auth.uid() or public.jt_is_admin());

drop policy if exists jt_profiles_self_update on public.jt_profiles;
create policy jt_profiles_self_update on public.jt_profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from public.jt_profiles where id = auth.uid()));

drop policy if exists jt_profiles_admin_all on public.jt_profiles;
create policy jt_profiles_admin_all on public.jt_profiles
  for all to authenticated
  using (public.jt_is_admin())
  with check (public.jt_is_admin());

drop policy if exists jt_bewerbungen_select on public.jt_bewerbungen;
create policy jt_bewerbungen_select on public.jt_bewerbungen
  for select to authenticated
  using (user_id = auth.uid() or public.jt_is_admin());

drop policy if exists jt_bewerbungen_modify on public.jt_bewerbungen;
create policy jt_bewerbungen_modify on public.jt_bewerbungen
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists jt_files_select on public.jt_files;
create policy jt_files_select on public.jt_files
  for select to authenticated
  using (user_id = auth.uid() or public.jt_is_admin());

drop policy if exists jt_files_modify on public.jt_files;
create policy jt_files_modify on public.jt_files
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists jt_timeline_select on public.jt_timeline;
create policy jt_timeline_select on public.jt_timeline
  for select to authenticated
  using (user_id = auth.uid() or public.jt_is_admin());

drop policy if exists jt_timeline_modify on public.jt_timeline;
create policy jt_timeline_modify on public.jt_timeline
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- Storage bucket + policies
-- ============================================================
insert into storage.buckets (id, name, public)
values ('jt-files', 'jt-files', false)
on conflict (id) do nothing;

drop policy if exists jt_storage_select on storage.objects;
create policy jt_storage_select on storage.objects
  for select to authenticated
  using (bucket_id = 'jt-files' and ((storage.foldername(name))[1] = auth.uid()::text or public.jt_is_admin()));

drop policy if exists jt_storage_insert on storage.objects;
create policy jt_storage_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'jt-files' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists jt_storage_delete on storage.objects;
create policy jt_storage_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'jt-files' and ((storage.foldername(name))[1] = auth.uid()::text or public.jt_is_admin()));

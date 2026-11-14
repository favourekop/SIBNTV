-- SIBNTV media, live-TV and creator workflow foundation
create table if not exists public.media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title_id uuid references public.titles(id) on delete set null,
  storage_path text not null unique,
  original_filename text not null,
  mime_type text not null,
  file_size_bytes bigint not null check (file_size_bytes > 0),
  processing_status text not null default 'uploaded' check (processing_status in ('uploaded','queued','processing','ready','failed')),
  playback_asset_id text,
  playback_manifest_url text,
  processing_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists media_assets_owner_idx on public.media_assets(owner_id,created_at desc);
create index if not exists media_assets_status_idx on public.media_assets(processing_status,created_at);

create table if not exists public.live_channels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  channel_id uuid not null references public.creator_channels(id) on delete cascade,
  title text not null,
  description text not null default '',
  status text not null default 'offline' check (status in ('offline','scheduled','live','ended','suspended')),
  ingest_provider text,
  ingest_stream_id text,
  playback_url text,
  scheduled_start timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists live_channels_status_idx on public.live_channels(status,scheduled_start);

create table if not exists public.creator_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  channel_name text not null,
  portfolio_url text,
  description text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.billing_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  processed_at timestamptz,
  processing_error text,
  created_at timestamptz not null default now(),
  unique(provider,provider_event_id)
);

alter table public.media_assets enable row level security;
alter table public.live_channels enable row level security;
alter table public.creator_applications enable row level security;
alter table public.billing_webhook_events enable row level security;

drop policy if exists "Owners and admins view media assets" on public.media_assets;
create policy "Owners and admins view media assets" on public.media_assets
for select to authenticated using (owner_id = (select auth.uid()) or public.current_user_role() = 'admin');
drop policy if exists "Creators upload media metadata" on public.media_assets;
create policy "Creators upload media metadata" on public.media_assets
for insert to authenticated with check (owner_id = (select auth.uid()) and public.current_user_role() in ('creator','admin'));
drop policy if exists "Owners update media metadata" on public.media_assets;
create policy "Owners update media metadata" on public.media_assets
for update to authenticated using (owner_id = (select auth.uid()) or public.current_user_role() = 'admin')
with check (owner_id = (select auth.uid()) or public.current_user_role() = 'admin');

drop policy if exists "Public can view live channels" on public.live_channels;
create policy "Public can view live channels" on public.live_channels
for select to anon,authenticated using (status = 'live' or owner_id = (select auth.uid()) or public.current_user_role() = 'admin');
drop policy if exists "Creators manage own live channels" on public.live_channels;
create policy "Creators manage own live channels" on public.live_channels
for all to authenticated using ((owner_id = (select auth.uid()) and public.current_user_role() in ('creator','admin')) or public.current_user_role() = 'admin')
with check ((owner_id = (select auth.uid()) and public.current_user_role() in ('creator','admin')) or public.current_user_role() = 'admin');

drop policy if exists "Users manage own creator applications" on public.creator_applications;
create policy "Users manage own creator applications" on public.creator_applications
for select to authenticated using (user_id = (select auth.uid()) or public.current_user_role() = 'admin');
drop policy if exists "Users submit creator applications" on public.creator_applications;
create policy "Users submit creator applications" on public.creator_applications
for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Admins review creator applications" on public.creator_applications;
create policy "Admins review creator applications" on public.creator_applications
for update to authenticated using (public.current_user_role() = 'admin') with check (public.current_user_role() = 'admin');

-- Private source uploads; playback delivery should use signed URLs from a video provider.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('sibntv-media','sibntv-media',false,5368709120,
  array['video/mp4','video/webm','video/quicktime','image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "Creators upload to own SIBNTV folder" on storage.objects;
create policy "Creators upload to own SIBNTV folder" on storage.objects
for insert to authenticated with check (
  bucket_id = 'sibntv-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and public.current_user_role() in ('creator','admin')
);
drop policy if exists "Creators read own SIBNTV files" on storage.objects;
create policy "Creators read own SIBNTV files" on storage.objects
for select to authenticated using (
  bucket_id = 'sibntv-media'
  and ((storage.foldername(name))[1] = (select auth.uid())::text or public.current_user_role() = 'admin')
);
drop policy if exists "Creators delete own SIBNTV files" on storage.objects;
create policy "Creators delete own SIBNTV files" on storage.objects
for delete to authenticated using (
  bucket_id = 'sibntv-media'
  and ((storage.foldername(name))[1] = (select auth.uid())::text or public.current_user_role() = 'admin')
);

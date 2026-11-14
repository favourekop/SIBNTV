-- SIBNTV full-stack foundation
-- Apply this migration to the SIBNTV Supabase project only after reviewing the project settings.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  role text not null default 'viewer' check (role in ('viewer','creator','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.guard_profile_role()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null and new.role is distinct from old.role then
    raise exception 'Profile roles can only be changed by a trusted server operation';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_guard_role on public.profiles;
create trigger profiles_guard_role
before update on public.profiles
for each row execute procedure public.guard_profile_role();

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid()
$$;

create table if not exists public.titles (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid references public.profiles(id) on delete set null,
  title text not null,
  slug text unique,
  synopsis text not null default '',
  category text not null default 'Drama',
  content_type text not null default 'film' check (content_type in ('film','series','documentary','short','live')),
  poster_url text,
  trailer_url text,
  playback_asset_id text,
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  release_year integer check (release_year is null or release_year between 1888 and 2200),
  status text not null default 'draft' check (status in ('draft','in_review','published','archived','rejected')),
  featured boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists titles_status_published_idx on public.titles(status, published_at desc);
create index if not exists titles_creator_idx on public.titles(creator_id);
create index if not exists titles_category_idx on public.titles(category);

create table if not exists public.watchlist (
  user_id uuid not null references public.profiles(id) on delete cascade,
  title_id uuid not null references public.titles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, title_id)
);

create table if not exists public.creator_channels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text not null default '',
  logo_url text,
  status text not null default 'pending' check (status in ('pending','approved','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null,
  provider_customer_id text,
  provider_subscription_id text unique,
  plan_code text not null,
  status text not null default 'pending' check (status in ('pending','active','past_due','cancelled','expired')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists subscriptions_user_status_idx on public.subscriptions(user_id, status);

create table if not exists public.playback_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  title_id uuid not null references public.titles(id) on delete cascade,
  event_type text not null check (event_type in ('started','progress','completed')),
  position_seconds integer not null default 0 check (position_seconds >= 0),
  occurred_at timestamptz not null default now()
);

create index if not exists playback_events_user_time_idx on public.playback_events(user_id, occurred_at desc);

alter table public.profiles enable row level security;
alter table public.titles enable row level security;
alter table public.watchlist enable row level security;
alter table public.creator_channels enable row level security;
alter table public.subscriptions enable row level security;
alter table public.playback_events enable row level security;

drop policy if exists "Profiles are viewable by their owner" on public.profiles;
create policy "Profiles are viewable by their owner"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or public.current_user_role() = 'admin');

drop policy if exists "Profiles are editable by their owner" on public.profiles;
create policy "Profiles are editable by their owner"
on public.profiles for update to authenticated
using (id = (select auth.uid()) or public.current_user_role() = 'admin')
with check (id = (select auth.uid()) or public.current_user_role() = 'admin');

drop policy if exists "Published titles are public" on public.titles;
create policy "Published titles are public"
on public.titles for select to anon, authenticated
using (status = 'published' or creator_id = (select auth.uid()) or public.current_user_role() = 'admin');

drop policy if exists "Creators can create their own titles" on public.titles;
create policy "Creators can create their own titles"
on public.titles for insert to authenticated
with check (creator_id = (select auth.uid()) and public.current_user_role() in ('creator','admin'));

drop policy if exists "Creators and admins can update titles" on public.titles;
create policy "Creators and admins can update titles"
on public.titles for update to authenticated
using ((creator_id = (select auth.uid()) and public.current_user_role() = 'creator') or public.current_user_role() = 'admin')
with check ((creator_id = (select auth.uid()) and public.current_user_role() = 'creator') or public.current_user_role() = 'admin');

drop policy if exists "Admins can delete titles" on public.titles;
create policy "Admins can delete titles"
on public.titles for delete to authenticated
using (public.current_user_role() = 'admin');

drop policy if exists "Users manage their own watchlist" on public.watchlist;
create policy "Users manage their own watchlist"
on public.watchlist for all to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Creators manage their channels" on public.creator_channels;
create policy "Creators manage their channels"
on public.creator_channels for all to authenticated
using (owner_id = (select auth.uid()) or public.current_user_role() = 'admin')
with check ((owner_id = (select auth.uid()) and public.current_user_role() in ('creator','admin')) or public.current_user_role() = 'admin');

drop policy if exists "Users view their subscriptions" on public.subscriptions;
create policy "Users view their subscriptions"
on public.subscriptions for select to authenticated
using (user_id = (select auth.uid()) or public.current_user_role() = 'admin');

drop policy if exists "Users view their playback history" on public.playback_events;
create policy "Users view their playback history"
on public.playback_events for select to authenticated
using (user_id = (select auth.uid()) or public.current_user_role() = 'admin');

drop policy if exists "Users add their playback events" on public.playback_events;
create policy "Users add their playback events"
on public.playback_events for insert to authenticated
with check (user_id = (select auth.uid()));

grant select on public.titles to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.watchlist to authenticated;
grant select, insert, update, delete on public.creator_channels to authenticated;
grant select on public.subscriptions to authenticated;
grant select, insert on public.playback_events to authenticated;

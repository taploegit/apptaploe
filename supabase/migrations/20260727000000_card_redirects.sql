drop function if exists public.resolve_card_redirect(text);
drop function if exists public.claim_card_redirect(text);
drop function if exists public.track_card_redirect_click(uuid, text, text);

create table if not exists public.card_redirects (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid references public.app_users(id) on delete cascade,
  slug text not null unique,
  label text not null default 'Card redirect',
  destination_url text,
  status text not null default 'draft',
  click_count integer not null default 0 check (click_count >= 0),
  last_clicked_at timestamptz,
  claimed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.card_redirect_events (
  id uuid primary key default gen_random_uuid(),
  redirect_id uuid not null references public.card_redirects(id) on delete cascade,
  owner_user_id uuid references public.app_users(id) on delete set null,
  user_agent text,
  referrer text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

drop policy if exists "card_redirects owner read" on public.card_redirects;
drop policy if exists "card_redirects owner insert" on public.card_redirects;
drop policy if exists "card_redirects owner update" on public.card_redirects;
drop policy if exists "card_redirects owner delete" on public.card_redirects;
drop policy if exists "card_redirects public read active" on public.card_redirects;
drop policy if exists "card_redirect_events owner read" on public.card_redirect_events;

drop index if exists card_redirects_physical_card_id_idx;
drop index if exists card_redirects_active_slug_idx;

alter table public.card_redirects
  add column if not exists claimed_at timestamptz,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz,
  drop constraint if exists card_redirects_one_per_card,
  drop constraint if exists card_redirects_physical_card_id_fkey,
  drop constraint if exists card_redirects_slug_check,
  drop constraint if exists card_redirects_slug_format,
  drop constraint if exists card_redirects_destination_url_check,
  drop constraint if exists card_redirects_destination_url_format,
  drop constraint if exists card_redirects_status_check,
  drop constraint if exists card_redirects_status_value,
  drop column if exists physical_card_id,
  alter column owner_user_id drop not null,
  alter column destination_url drop not null,
  alter column status set default 'draft';

alter table public.card_redirect_events
  drop constraint if exists card_redirect_events_physical_card_id_fkey,
  drop column if exists physical_card_id;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'card_redirects_slug_format'
      and conrelid = 'public.card_redirects'::regclass
  ) then
    alter table public.card_redirects
      add constraint card_redirects_slug_format
      check (slug ~ '^[a-z0-9][a-z0-9-]{2,80}$');
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'card_redirects_destination_url_format'
      and conrelid = 'public.card_redirects'::regclass
  ) then
    alter table public.card_redirects
      add constraint card_redirects_destination_url_format
      check (destination_url is null or destination_url ~* '^https?://');
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'card_redirects_status_value'
      and conrelid = 'public.card_redirects'::regclass
  ) then
    alter table public.card_redirects
      add constraint card_redirects_status_value
      check (status in ('draft', 'active', 'inactive'));
  end if;
end;
$$;

create index if not exists card_redirects_owner_user_id_idx
  on public.card_redirects(owner_user_id);

create index if not exists card_redirects_active_slug_idx
  on public.card_redirects(slug)
  where status = 'active' and destination_url is not null;

create index if not exists card_redirect_events_redirect_id_created_at_idx
  on public.card_redirect_events(redirect_id, created_at desc);

alter table public.card_redirects enable row level security;
alter table public.card_redirect_events enable row level security;

create policy "card_redirects owner read"
on public.card_redirects
for select
to authenticated
using (
  exists (
    select 1
    from public.app_users u
    where u.auth_user_id = auth.uid()
      and u.id = card_redirects.owner_user_id
  )
);

create policy "card_redirects owner insert"
on public.card_redirects
for insert
to authenticated
with check (
  exists (
    select 1
    from public.app_users u
    where u.auth_user_id = auth.uid()
      and u.id = card_redirects.owner_user_id
  )
);

create policy "card_redirects owner update"
on public.card_redirects
for update
to authenticated
using (
  exists (
    select 1
    from public.app_users u
    where u.auth_user_id = auth.uid()
      and u.id = card_redirects.owner_user_id
  )
)
with check (
  exists (
    select 1
    from public.app_users u
    where u.auth_user_id = auth.uid()
      and u.id = card_redirects.owner_user_id
  )
);

create policy "card_redirects owner delete"
on public.card_redirects
for delete
to authenticated
using (
  exists (
    select 1
    from public.app_users u
    where u.auth_user_id = auth.uid()
      and u.id = card_redirects.owner_user_id
  )
);

create policy "card_redirect_events owner read"
on public.card_redirect_events
for select
to authenticated
using (
  exists (
    select 1
    from public.app_users u
    where u.auth_user_id = auth.uid()
      and u.id = card_redirect_events.owner_user_id
  )
);

create or replace function public.resolve_card_redirect(p_slug text)
returns table (
  id uuid,
  owner_user_id uuid,
  slug text,
  label text,
  destination_url text,
  status text,
  click_count integer,
  last_clicked_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    cr.id,
    cr.owner_user_id,
    cr.slug,
    cr.label,
    cr.destination_url,
    cr.status,
    cr.click_count,
    cr.last_clicked_at,
    cr.claimed_at,
    cr.created_at,
    cr.updated_at
  from public.card_redirects cr
  where cr.slug = lower(trim(p_slug))
    and cr.status = 'active'
    and nullif(trim(cr.destination_url), '') is not null
  limit 1;
$$;

create or replace function public.claim_card_redirect(p_slug text)
returns table (
  id uuid,
  owner_user_id uuid,
  slug text,
  label text,
  destination_url text,
  status text,
  click_count integer,
  last_clicked_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_redirect_id uuid;
begin
  select u.id
    into v_user_id
  from public.app_users u
  where u.auth_user_id = auth.uid()
  limit 1;

  if v_user_id is null then
    return;
  end if;

  select cr.id
    into v_redirect_id
  from public.card_redirects cr
  where cr.slug = lower(trim(p_slug))
    and (cr.owner_user_id is null or cr.owner_user_id = v_user_id)
  limit 1;

  if v_redirect_id is null then
    return;
  end if;

  update public.card_redirects
  set owner_user_id = v_user_id,
      claimed_at = coalesce(claimed_at, now()),
      updated_at = now()
  where card_redirects.id = v_redirect_id;

  return query
  select
    cr.id,
    cr.owner_user_id,
    cr.slug,
    cr.label,
    cr.destination_url,
    cr.status,
    cr.click_count,
    cr.last_clicked_at,
    cr.claimed_at,
    cr.created_at,
    cr.updated_at
  from public.card_redirects cr
  where cr.id = v_redirect_id;
end;
$$;

create or replace function public.track_card_redirect_click(
  p_redirect_id uuid,
  p_user_agent text default null,
  p_referrer text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_redirect public.card_redirects%rowtype;
begin
  select *
    into v_redirect
  from public.card_redirects cr
  where cr.id = p_redirect_id
    and cr.status = 'active'
    and nullif(trim(cr.destination_url), '') is not null;

  if not found then
    return;
  end if;

  update public.card_redirects
  set click_count = click_count + 1,
      last_clicked_at = now(),
      updated_at = now()
  where card_redirects.id = v_redirect.id;

  insert into public.card_redirect_events (
    redirect_id,
    owner_user_id,
    user_agent,
    referrer
  )
  values (
    v_redirect.id,
    v_redirect.owner_user_id,
    nullif(trim(p_user_agent), ''),
    nullif(trim(p_referrer), '')
  );
end;
$$;

grant execute on function public.resolve_card_redirect(text) to anon;
grant execute on function public.resolve_card_redirect(text) to authenticated;
grant execute on function public.claim_card_redirect(text) to authenticated;
grant execute on function public.track_card_redirect_click(uuid, text, text) to anon;
grant execute on function public.track_card_redirect_click(uuid, text, text) to authenticated;

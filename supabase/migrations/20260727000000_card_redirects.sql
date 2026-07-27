create table if not exists public.card_redirects (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.app_users(id) on delete cascade,
  physical_card_id uuid not null references public.physical_cards(id) on delete cascade,
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{2,80}$'),
  label text not null default 'Card redirect',
  destination_url text not null check (destination_url ~* '^https?://'),
  status text not null default 'active' check (status in ('active', 'inactive')),
  click_count integer not null default 0 check (click_count >= 0),
  last_clicked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz,
  created_at timestamptz not null default now(),
  constraint card_redirects_one_per_card unique (physical_card_id)
);

create table if not exists public.card_redirect_events (
  id uuid primary key default gen_random_uuid(),
  redirect_id uuid not null references public.card_redirects(id) on delete cascade,
  physical_card_id uuid references public.physical_cards(id) on delete set null,
  owner_user_id uuid references public.app_users(id) on delete set null,
  user_agent text,
  referrer text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists card_redirects_owner_user_id_idx
  on public.card_redirects(owner_user_id);

create index if not exists card_redirects_physical_card_id_idx
  on public.card_redirects(physical_card_id);

create index if not exists card_redirects_active_slug_idx
  on public.card_redirects(slug)
  where status = 'active';

create index if not exists card_redirect_events_redirect_id_created_at_idx
  on public.card_redirect_events(redirect_id, created_at desc);

alter table public.card_redirects enable row level security;
alter table public.card_redirect_events enable row level security;

drop policy if exists "card_redirects owner read" on public.card_redirects;
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

drop policy if exists "card_redirects owner insert" on public.card_redirects;
create policy "card_redirects owner insert"
on public.card_redirects
for insert
to authenticated
with check (
  exists (
    select 1
    from public.app_users u
    join public.physical_cards c on c.owner_user_id = u.id
    where u.auth_user_id = auth.uid()
      and u.id = card_redirects.owner_user_id
      and c.id = card_redirects.physical_card_id
  )
);

drop policy if exists "card_redirects owner update" on public.card_redirects;
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
    join public.physical_cards c on c.owner_user_id = u.id
    where u.auth_user_id = auth.uid()
      and u.id = card_redirects.owner_user_id
      and c.id = card_redirects.physical_card_id
  )
);

drop policy if exists "card_redirect_events owner read" on public.card_redirect_events;
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
  physical_card_id uuid,
  owner_user_id uuid,
  slug text,
  label text,
  destination_url text,
  status text,
  click_count integer,
  last_clicked_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    cr.id,
    cr.physical_card_id,
    cr.owner_user_id,
    cr.slug,
    cr.label,
    cr.destination_url,
    cr.status,
    cr.click_count,
    cr.last_clicked_at,
    cr.created_at,
    cr.updated_at
  from public.card_redirects cr
  where cr.slug = lower(trim(p_slug))
    and cr.status = 'active'
  limit 1;
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
  from public.card_redirects
  where id = p_redirect_id
    and status = 'active';

  if not found then
    return;
  end if;

  update public.card_redirects
  set click_count = click_count + 1,
      last_clicked_at = now(),
      updated_at = now()
  where id = v_redirect.id;

  insert into public.card_redirect_events (
    redirect_id,
    physical_card_id,
    owner_user_id,
    user_agent,
    referrer
  )
  values (
    v_redirect.id,
    v_redirect.physical_card_id,
    v_redirect.owner_user_id,
    nullif(trim(p_user_agent), ''),
    nullif(trim(p_referrer), '')
  );
end;
$$;

grant execute on function public.resolve_card_redirect(text) to anon;
grant execute on function public.resolve_card_redirect(text) to authenticated;
grant execute on function public.track_card_redirect_click(uuid, text, text) to anon;
grant execute on function public.track_card_redirect_click(uuid, text, text) to authenticated;

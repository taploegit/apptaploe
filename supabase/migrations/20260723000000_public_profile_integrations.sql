create or replace function public.public_profile_integrations(p_profile_id uuid)
returns table (
  id uuid,
  profile_id uuid,
  integration_id uuid,
  is_enabled boolean,
  display_label text,
  sort_order integer,
  user_id uuid,
  integration_type text,
  provider text,
  public_url text,
  status text
)
language sql
security definer
set search_path = public
as $$
  select
    pi.id,
    pi.profile_id,
    pi.integration_id,
    pi.is_enabled,
    pi.display_label,
    pi.sort_order,
    ui.user_id,
    ui.integration_type,
    ui.provider,
    ui.public_url,
    ui.status
  from public.profile_integrations pi
  join public.user_integrations ui on ui.id = pi.integration_id
  where pi.profile_id = p_profile_id
    and pi.is_enabled = true
    and ui.status = 'active'
    and nullif(trim(ui.public_url), '') is not null
  order by pi.sort_order;
$$;

grant execute on function public.public_profile_integrations(uuid) to anon;
grant execute on function public.public_profile_integrations(uuid) to authenticated;

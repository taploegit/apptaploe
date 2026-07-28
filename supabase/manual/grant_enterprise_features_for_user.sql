-- Manual data fix: grant Enterprise capabilities to one Taploe account.
--
-- Run this in the Supabase SQL editor for the target project.
-- This is intentionally not a schema migration because it updates production
-- account data for a specific user.

do $$
declare
  v_app_user_id uuid := '90a8d7ae-78d7-4b8d-be75-5878ea4fcde7';
  v_auth_user_id uuid := '9ca9a108-71dc-4f84-b439-721e39e6b54c';
  v_now timestamptz := now();
  v_access_until timestamptz := now() + interval '10 years';
  v_primary_org_id uuid;
  v_org_id uuid;
  v_subscription_id uuid;
begin
  if not exists (
    select 1
    from public.app_users
    where id = v_app_user_id
      and auth_user_id = v_auth_user_id
  ) then
    raise exception
      'No app_users row matches app_user_id % and auth_user_id %',
      v_app_user_id,
      v_auth_user_id;
  end if;

  -- app_users.plan_type only allows free/premium in the current schema.
  update public.app_users
  set
    plan_type = 'premium',
    status = 'active',
    updated_at = v_now
  where id = v_app_user_id
    and auth_user_id = v_auth_user_id;

  select om.org_id
  into v_primary_org_id
  from public.organization_members om
  join public.organizations o on o.id = om.org_id
  where om.user_id = v_app_user_id
    and om.status = 'active'
    and o.status = 'active'
  order by
    case om.role when 'owner' then 0 when 'admin' then 1 else 2 end,
    om.created_at desc
  limit 1;

  if v_primary_org_id is null then
    insert into public.organizations (
      name,
      slug,
      status,
      plan_type,
      created_by_user_id,
      created_at,
      updated_at
    )
    values (
      'Taploe Enterprise',
      'taploe-enterprise-90a8d7ae',
      'active',
      'enterprise',
      v_app_user_id,
      v_now,
      v_now
    )
    on conflict (slug) do update
    set
      status = 'active',
      plan_type = 'enterprise',
      created_by_user_id = coalesce(
        public.organizations.created_by_user_id,
        excluded.created_by_user_id
      ),
      updated_at = excluded.updated_at
    returning id into v_primary_org_id;

    if exists (
      select 1
      from public.organization_members
      where org_id = v_primary_org_id
        and user_id = v_app_user_id
    ) then
      update public.organization_members
      set
        role = 'owner',
        status = 'active',
        joined_at = coalesce(joined_at, v_now)
      where org_id = v_primary_org_id
        and user_id = v_app_user_id;
    else
      insert into public.organization_members (
        org_id,
        user_id,
        role,
        status,
        joined_at,
        created_at
      )
      values (
        v_primary_org_id,
        v_app_user_id,
        'owner',
        'active',
        v_now,
        v_now
      );
    end if;
  end if;

  -- Keep owned profiles attached to an organization so profile-level capability
  -- checks can also see the Enterprise grant.
  update public.digital_profiles
  set
    org_id = v_primary_org_id,
    updated_at = v_now
  where owner_user_id = v_app_user_id
    and org_id is null;

  -- The app currently loads the first active organization membership without
  -- an explicit order. Grant Enterprise to every active organization for this
  -- user so the effective plan is stable even if more than one membership exists.
  for v_org_id in
    select distinct om.org_id
    from public.organization_members om
    join public.organizations o on o.id = om.org_id
    where om.user_id = v_app_user_id
      and om.status = 'active'
      and o.status = 'active'
  loop
    update public.organizations
    set
      plan_type = 'enterprise',
      status = 'active',
      updated_at = v_now
    where id = v_org_id;

    select id
    into v_subscription_id
    from public.billing_subscriptions
    where scope = 'organization'
      and org_id = v_org_id
      and metadata ->> 'source' = 'manual_enterprise_sql'
    order by created_at desc
    limit 1;

    if v_subscription_id is null then
      insert into public.billing_subscriptions (
        scope,
        org_id,
        owner_user_id,
        plan_type,
        billing_interval,
        status,
        cancel_at_period_end,
        current_period_start,
        current_period_end,
        next_payment_at,
        quantity,
        currency,
        metadata,
        created_at,
        updated_at
      )
      values (
        'organization',
        v_org_id,
        v_app_user_id,
        'enterprise',
        'annual',
        'active',
        false,
        v_now,
        v_access_until,
        v_access_until,
        1,
        'MXN',
        jsonb_build_object(
          'source',
          'manual_enterprise_sql',
          'reason',
          'manual Enterprise feature grant',
          'app_user_id',
          v_app_user_id::text,
          'auth_user_id',
          v_auth_user_id::text
        ),
        v_now,
        v_now
      );
    else
      update public.billing_subscriptions
      set
        owner_user_id = v_app_user_id,
        plan_type = 'enterprise',
        billing_interval = 'annual',
        status = 'active',
        cancel_at_period_end = false,
        current_period_start = coalesce(current_period_start, v_now),
        current_period_end = v_access_until,
        next_payment_at = v_access_until,
        canceled_at = null,
        ended_at = null,
        grace_until = null,
        payment_issue = false,
        payment_action_required = false,
        quantity = greatest(quantity, 1),
        currency = coalesce(currency, 'MXN'),
        metadata = metadata || jsonb_build_object(
          'source',
          'manual_enterprise_sql',
          'reason',
          'manual Enterprise feature grant',
          'app_user_id',
          v_app_user_id::text,
          'auth_user_id',
          v_auth_user_id::text
        ),
        created_at = v_now,
        updated_at = v_now
      where id = v_subscription_id;
    end if;
  end loop;
end $$;

-- Verification: every returned organization should show enterprise + active.
select
  au.id as app_user_id,
  au.auth_user_id,
  au.plan_type as user_plan_type,
  o.id as org_id,
  o.name as org_name,
  o.plan_type as org_plan_type,
  om.role as org_role,
  bs.plan_type as subscription_plan_type,
  bs.status as subscription_status,
  bs.current_period_end
from public.app_users au
left join public.organization_members om
  on om.user_id = au.id
 and om.status = 'active'
left join public.organizations o
  on o.id = om.org_id
left join public.billing_subscriptions bs
  on bs.org_id = o.id
 and bs.scope = 'organization'
 and bs.metadata ->> 'source' = 'manual_enterprise_sql'
where au.id = '90a8d7ae-78d7-4b8d-be75-5878ea4fcde7'
  and au.auth_user_id = '9ca9a108-71dc-4f84-b439-721e39e6b54c'
order by o.created_at desc nulls last;

-- Billing and entitlement source of truth.
-- Individual plans live in app_users.plan_type: free | premium.
-- Team plans live in organizations.plan_type: business | enterprise.
-- Paid access is granted only by a non-expired billing_subscriptions row.

alter table public.app_users
  drop constraint if exists app_users_plan_type_check;

alter table public.app_users
  add constraint app_users_plan_type_check
  check (plan_type = any (array['free'::text, 'premium'::text]));

alter table public.organizations
  drop constraint if exists organizations_plan_type_check;

alter table public.organizations
  add constraint organizations_plan_type_check
  check (plan_type = any (array['business'::text, 'enterprise'::text]));

create table if not exists public.billing_subscriptions (
  id uuid primary key default gen_random_uuid(),
  scope text not null check (scope in ('user', 'organization')),
  user_id uuid references public.app_users(id),
  org_id uuid references public.organizations(id),
  owner_user_id uuid not null references public.app_users(id),
  plan_type text not null check (plan_type in ('premium', 'business', 'enterprise')),
  billing_interval text not null check (billing_interval in ('monthly', 'annual')),
  status text not null default 'trialing'
    check (status in (
      'trialing',
      'active',
      'past_due',
      'grace_period',
      'canceled',
      'expired',
      'unpaid'
    )),
  cancel_at_period_end boolean not null default false,
  trial_start timestamptz,
  trial_end timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  grace_until timestamptz,
  canceled_at timestamptz,
  ended_at timestamptz,
  stripe_customer_id text,
  stripe_subscription_id text unique,
  stripe_price_id text,
  stripe_product_id text,
  last_payment_at timestamptz,
  next_payment_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz,
  created_at timestamptz not null default now(),
  constraint billing_subscription_scope_target check (
    (scope = 'user' and user_id is not null and org_id is null)
    or
    (scope = 'organization' and org_id is not null)
  )
);

create index if not exists billing_subscriptions_user_idx
on public.billing_subscriptions(user_id);

create index if not exists billing_subscriptions_org_idx
on public.billing_subscriptions(org_id);

create index if not exists billing_subscriptions_stripe_customer_idx
on public.billing_subscriptions(stripe_customer_id);

create index if not exists billing_subscriptions_status_period_idx
on public.billing_subscriptions(status, current_period_end, grace_until);

create table if not exists public.billing_invoices (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.billing_subscriptions(id),
  user_id uuid references public.app_users(id),
  org_id uuid references public.organizations(id),
  stripe_invoice_id text unique,
  stripe_payment_intent_id text,
  status text not null check (
    status in ('draft', 'open', 'paid', 'void', 'uncollectible', 'failed')
  ),
  currency text not null default 'MXN',
  amount_due numeric not null default 0,
  amount_paid numeric not null default 0,
  amount_remaining numeric not null default 0,
  hosted_invoice_url text,
  invoice_pdf text,
  period_start timestamptz,
  period_end timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.billing_events (
  id uuid primary key default gen_random_uuid(),
  stripe_event_id text not null unique,
  event_type text not null,
  processed_at timestamptz not null default now(),
  payload jsonb not null
);

create or replace function public.billing_subscription_grants_access(
  p_status text,
  p_trial_end timestamptz,
  p_current_period_end timestamptz,
  p_grace_until timestamptz
)
returns boolean
language sql
stable
as $$
  select
    p_status in ('trialing', 'active', 'past_due', 'grace_period')
    and coalesce(p_grace_until, p_current_period_end, p_trial_end, now()) >= now();
$$;

create or replace function public.expire_overdue_subscriptions()
returns void
language plpgsql
as $$
begin
  update public.billing_subscriptions
  set
    status = 'expired',
    ended_at = coalesce(ended_at, now()),
    updated_at = now()
  where status in ('trialing', 'active', 'past_due', 'grace_period')
    and coalesce(grace_until, current_period_end, trial_end) < now();

  update public.app_users u
  set
    plan_type = 'free',
    updated_at = now()
  from public.billing_subscriptions s
  where s.scope = 'user'
    and s.user_id = u.id
    and s.status in ('expired', 'canceled', 'unpaid')
    and u.plan_type <> 'free';
end;
$$;

create or replace view public.effective_user_plans as
select
  u.id as user_id,
  u.username,
  u.email,
  u.plan_type as individual_plan,
  om.org_id,
  om.role as organization_role,
  om.status as membership_status,
  o.name as organization_name,
  o.plan_type as organization_plan,
  os.status as organization_subscription_status,
  os.current_period_end as organization_current_period_end,
  os.grace_until as organization_grace_until,
  us.status as user_subscription_status,
  us.current_period_end as user_current_period_end,
  us.grace_until as user_grace_until,
  case
    when om.status = 'active'
      and o.id is not null
      and public.billing_subscription_grants_access(
        os.status,
        os.trial_end,
        os.current_period_end,
        os.grace_until
      )
      then o.plan_type
    when public.billing_subscription_grants_access(
        us.status,
        us.trial_end,
        us.current_period_end,
        us.grace_until
      )
      and u.plan_type = 'premium'
      then 'premium'
    else 'free'
  end as effective_plan
from public.app_users u
left join public.organization_members om
  on om.user_id = u.id
  and om.status = 'active'
left join public.organizations o
  on o.id = om.org_id
left join public.billing_subscriptions os
  on os.scope = 'organization'
  and os.org_id = o.id
left join public.billing_subscriptions us
  on us.scope = 'user'
  and us.user_id = u.id;

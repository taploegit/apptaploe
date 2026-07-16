alter table public.app_users
  add column if not exists plan_type text not null default 'free';

alter table public.app_users
  drop constraint if exists app_users_plan_type_check;

alter table public.app_users
  add constraint app_users_plan_type_check
  check (plan_type = any (array[
    'free'::text,
    'pro'::text,
    'premium'::text,
    'business'::text,
    'enterprise'::text
  ]));

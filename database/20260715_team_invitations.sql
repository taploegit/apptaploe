create table if not exists public.organization_invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  invited_user_id uuid not null references public.app_users(id) on delete cascade,
  invited_by_user_id uuid not null references public.app_users(id),
  role text not null default 'member'
    check (role in ('admin', 'member', 'viewer')),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  responded_at timestamp with time zone,
  created_at timestamp with time zone not null default now()
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'organization_members_org_user_unique'
      and conrelid = 'public.organization_members'::regclass
  ) then
    alter table public.organization_members
      add constraint organization_members_org_user_unique unique (org_id, user_id);
  end if;
end $$;

create unique index if not exists organization_invitations_pending_unique
  on public.organization_invitations (org_id, invited_user_id)
  where status = 'pending';

create index if not exists organization_invitations_invited_user_idx
  on public.organization_invitations (invited_user_id, status, created_at desc);

create index if not exists organization_invitations_org_idx
  on public.organization_invitations (org_id, status, created_at desc);

create index if not exists app_notifications_team_invitation_idx
  on public.app_notifications ((metadata->>'invitation_id'))
  where notification_type = 'team_invitation';

create or replace function public.current_app_user_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.app_users
  where auth_user_id = auth.uid()
  limit 1
$$;

create or replace function public.is_org_member(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members
    where org_id = p_org_id
      and user_id = public.current_app_user_id()
      and status = 'active'
  )
$$;

create or replace function public.has_org_role(p_org_id uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members
    where org_id = p_org_id
      and user_id = public.current_app_user_id()
      and status = 'active'
      and role = any(p_roles)
  )
$$;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.organization_invitations enable row level security;

drop policy if exists "Users can create their own company"
on public.organizations;

create policy "Users can create their own company"
on public.organizations
for insert
to authenticated
with check (created_by_user_id = public.current_app_user_id());

drop policy if exists "Company members can read companies"
on public.organizations;

create policy "Company members can read companies"
on public.organizations
for select
to authenticated
using (
  created_by_user_id = public.current_app_user_id()
  or public.is_org_member(id)
);

drop policy if exists "Company owners and admins can update companies"
on public.organizations;

create policy "Company owners and admins can update companies"
on public.organizations
for update
to authenticated
using (public.has_org_role(id, array['owner', 'admin']))
with check (public.has_org_role(id, array['owner', 'admin']));

drop policy if exists "Users can create owner membership for own company"
on public.organization_members;

create policy "Users can create owner membership for own company"
on public.organization_members
for insert
to authenticated
with check (
  user_id = public.current_app_user_id()
  and role = 'owner'
  and status = 'active'
  and exists (
    select 1
    from public.organizations
    where id = org_id
      and created_by_user_id = public.current_app_user_id()
  )
);

drop policy if exists "Invited users can join invited company"
on public.organization_members;

create policy "Invited users can join invited company"
on public.organization_members
for insert
to authenticated
with check (
  user_id = public.current_app_user_id()
  and status = 'active'
  and exists (
    select 1
    from public.organization_invitations
    where org_id = organization_members.org_id
      and invited_user_id = public.current_app_user_id()
      and status = 'pending'
      and role = organization_members.role
  )
);

drop policy if exists "Company members can read memberships"
on public.organization_members;

create policy "Company members can read memberships"
on public.organization_members
for select
to authenticated
using (
  user_id = public.current_app_user_id()
  or public.is_org_member(org_id)
);

drop policy if exists "Invited users can update own membership"
on public.organization_members;

create policy "Invited users can update own membership"
on public.organization_members
for update
to authenticated
using (user_id = public.current_app_user_id())
with check (user_id = public.current_app_user_id());

drop policy if exists "Owners and admins can invite members"
on public.organization_invitations;

create policy "Owners and admins can invite members"
on public.organization_invitations
for insert
to authenticated
with check (
  invited_by_user_id = public.current_app_user_id()
  and public.has_org_role(org_id, array['owner', 'admin'])
);

drop policy if exists "Invitation participants can read invitations"
on public.organization_invitations;

create policy "Invitation participants can read invitations"
on public.organization_invitations
for select
to authenticated
using (
  invited_user_id = public.current_app_user_id()
  or invited_by_user_id = public.current_app_user_id()
  or public.has_org_role(org_id, array['owner', 'admin'])
);

drop policy if exists "Invited users can respond to invitations"
on public.organization_invitations;

create policy "Invited users can respond to invitations"
on public.organization_invitations
for update
to authenticated
using (
  invited_user_id = public.current_app_user_id()
  and status = 'pending'
)
with check (invited_user_id = public.current_app_user_id());

drop policy if exists "Users can link own profiles to own company"
on public.digital_profiles;

create policy "Users can link own profiles to own company"
on public.digital_profiles
for update
to authenticated
using (owner_user_id = public.current_app_user_id())
with check (owner_user_id = public.current_app_user_id());

drop policy if exists "Members can create team invitation notifications"
on public.app_notifications;

create policy "Members can create team invitation notifications"
on public.app_notifications
for insert
to authenticated
with check (
  notification_type = 'team_invitation'
  and (metadata->>'org_id') is not null
  and public.has_org_role((metadata->>'org_id')::uuid, array['owner', 'admin'])
);

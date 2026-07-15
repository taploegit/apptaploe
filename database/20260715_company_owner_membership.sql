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

create index if not exists organizations_created_by_user_idx
  on public.organizations (created_by_user_id, created_at desc);

create index if not exists organization_members_user_status_idx
  on public.organization_members (user_id, status, created_at desc);

create index if not exists digital_profiles_owner_org_idx
  on public.digital_profiles (owner_user_id, org_id);

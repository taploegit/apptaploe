-- Adds a real account username separate from app_users.full_name.
-- Run the duplicate check first. If it returns rows, rename those users before
-- creating the unique index.

alter table public.app_users
  add column if not exists username text;

drop index if exists public.app_users_username_unique_idx;

update public.app_users
set username = regexp_replace(
  regexp_replace(
    translate(
      lower(coalesce(nullif(trim(username), ''), nullif(trim(full_name), ''), split_part(email::text, '@', 1))),
      'áàäâéèëêíìïîóòöôúùüûñ',
      'aaaaeeeeiiiioooouuuun'
    ),
    '[^a-z0-9]+',
    '-',
    'g'
  ),
  '(^-+|-+$)',
  '',
  'g'
)
where username is null or trim(username) = '';

update public.app_users
set username = 'taploe-' || id::text
where username is null or length(username) < 3;

select
  lower(trim(username)) as username,
  count(*) as duplicate_count,
  array_agg(id order by created_at) as user_ids
from public.app_users
group by lower(trim(username))
having count(*) > 1;

alter table public.app_users
  alter column username set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'app_users_username_format_check'
      and conrelid = 'public.app_users'::regclass
  ) then
    alter table public.app_users
      add constraint app_users_username_format_check
      check (username ~ '^[a-z0-9][a-z0-9-]{2,60}$') not valid;
  end if;
end $$;

alter table public.app_users
  validate constraint app_users_username_format_check;

create unique index if not exists app_users_username_column_unique_idx
  on public.app_users (lower(username));

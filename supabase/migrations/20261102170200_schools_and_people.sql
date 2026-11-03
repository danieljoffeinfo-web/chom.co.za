-- Schools, school years, people and their roles.
--
-- Every school-scoped row carries school_id. Where one row points at another, the
-- foreign key includes school_id too, so the database itself rejects links across
-- schools (for example, a parent at one school linked to a child at another).

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  ednana_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.schools is 'Each school on the platform.';
comment on column public.schools.ednana_id is 'The school''s identifier in Ednana, for the future sync.';

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete restrict,
  label text not null check (length(trim(label)) > 0),
  starts_on date not null,
  ends_on date not null,
  curriculum_id uuid not null references public.curricula (id) on delete restrict,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on > starts_on),
  unique (school_id, label),
  unique (id, school_id)
);

comment on table public.academic_years is
  'A school''s years. Classes belong to a year, so each year keeps its own history. The curriculum is chosen per year.';

create unique index academic_years_one_current_per_school
  on public.academic_years (school_id) where is_current;
create index academic_years_curriculum_id_idx on public.academic_years (curriculum_id);

-- One row per person. A person exists here before they have a login (for example a
-- learner imported from Ednana), and is linked to their login when they first sign in.
create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users (id) on delete set null,
  full_name text not null check (length(trim(full_name)) > 0),
  preferred_name text check (preferred_name is null or length(trim(preferred_name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'One row per person, across all schools. user_id links to their login once they have one.';

-- Who belongs to which school, and as what. One person can hold several roles, at one
-- school or across schools (a teacher who is also a parent; a parent with children at
-- two schools).
create table public.school_memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete restrict,
  profile_id uuid not null references public.profiles (id) on delete restrict,
  role public.membership_role not null,
  status public.membership_status not null default 'active',
  ednana_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, profile_id, role),
  unique (school_id, role, ednana_id)
);

comment on table public.school_memberships is
  'A person''s role at a school. Only active memberships grant access.';

create index school_memberships_profile_id_idx on public.school_memberships (profile_id);

-- Links a parent to a child. Both must hold the matching role at the same school: the
-- composite foreign keys enforce it.
create table public.guardianships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  parent_profile_id uuid not null,
  student_profile_id uuid not null,
  parent_role public.membership_role not null default 'parent' check (parent_role = 'parent'),
  student_role public.membership_role not null default 'student' check (student_role = 'student'),
  relationship text,
  ednana_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (parent_profile_id <> student_profile_id),
  unique (school_id, parent_profile_id, student_profile_id),
  unique (school_id, ednana_id),
  foreign key (school_id, parent_profile_id, parent_role)
    references public.school_memberships (school_id, profile_id, role) on delete restrict,
  foreign key (school_id, student_profile_id, student_role)
    references public.school_memberships (school_id, profile_id, role) on delete restrict
);

comment on table public.guardianships is 'Which parent is linked to which child, at a school.';

create index guardianships_parent_profile_id_idx on public.guardianships (parent_profile_id);
create index guardianships_student_profile_id_idx on public.guardianships (student_profile_id);

create trigger schools_set_updated_at before update on public.schools
  for each row execute function private.set_updated_at();
create trigger academic_years_set_updated_at before update on public.academic_years
  for each row execute function private.set_updated_at();
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();
create trigger school_memberships_set_updated_at before update on public.school_memberships
  for each row execute function private.set_updated_at();
create trigger guardianships_set_updated_at before update on public.guardianships
  for each row execute function private.set_updated_at();

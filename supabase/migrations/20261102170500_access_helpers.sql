-- Access helpers used by row-level security policies.
--
-- Each answers one question about the signed-in person, such as "do they teach this
-- class?". They run as the table owner (security definer) so that checking access to
-- one table never triggers the policies of another, which would recurse. Each one only
-- ever answers about the caller, so exposing the answer leaks nothing.
--
-- Only ACTIVE memberships count. Deactivating a membership removes access at once.

-- The profile of the signed-in person, or null.
create function private.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id from public.profiles p where p.user_id = (select auth.uid())
$$;

-- Does the signed-in person hold this active role at this school?
create function private.has_role(p_school_id uuid, p_role public.membership_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.school_memberships m
    where m.school_id = p_school_id
      and m.role = p_role
      and m.status = 'active'
      and m.profile_id = (select private.current_profile_id())
  )
$$;

-- Does the signed-in person hold any active role at this school?
create function private.is_member(p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.school_memberships m
    where m.school_id = p_school_id
      and m.status = 'active'
      and m.profile_id = (select private.current_profile_id())
  )
$$;

create function private.is_school_admin(p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_role(p_school_id, 'school_admin')
$$;

-- Does the signed-in person (as an active teacher) teach any subject in this class?
create function private.teaches_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teaching_allocations ta
    join public.class_subjects cs on cs.id = ta.class_subject_id
    join public.school_memberships m
      on m.school_id = ta.school_id
     and m.profile_id = ta.teacher_profile_id
     and m.role = 'teacher'
     and m.status = 'active'
    where cs.class_id = p_class_id
      and ta.teacher_profile_id = (select private.current_profile_id())
  )
$$;

-- Is the signed-in person (as an active student) in this class?
create function private.is_enrolled_in(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.enrolments e
    join public.school_memberships m
      on m.school_id = e.school_id
     and m.profile_id = e.student_profile_id
     and m.role = 'student'
     and m.status = 'active'
    where e.class_id = p_class_id
      and e.student_profile_id = (select private.current_profile_id())
  )
$$;

-- Is the signed-in person (as an active parent) linked to this child?
create function private.is_parent_of(p_student_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.guardianships g
    join public.school_memberships m
      on m.school_id = g.school_id
     and m.profile_id = g.parent_profile_id
     and m.role = 'parent'
     and m.status = 'active'
    where g.student_profile_id = p_student_profile_id
      and g.parent_profile_id = (select private.current_profile_id())
  )
$$;

-- Is one of the signed-in person's children in this class?
create function private.is_parent_in_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.enrolments e
    where e.class_id = p_class_id
      and private.is_parent_of(e.student_profile_id)
  )
$$;

-- Does the signed-in person teach a class this learner is in?
create function private.teaches_student(p_student_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.enrolments e
    where e.student_profile_id = p_student_profile_id
      and private.teaches_class(e.class_id)
  )
$$;

-- Can the signed-in person see this class? Admins of its school, its teachers, its
-- learners, and parents of its learners.
create function private.can_view_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.classes c
    where c.id = p_class_id
      and (
        private.is_school_admin(c.school_id)
        or private.teaches_class(c.id)
        or private.is_enrolled_in(c.id)
        or private.is_parent_in_class(c.id)
      )
  )
$$;

create function private.can_view_class_subject(p_class_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.class_subjects cs
    where cs.id = p_class_subject_id
      and private.can_view_class(cs.class_id)
  )
$$;

-- Can the signed-in person see this person's name?
--   * themselves
--   * school admins: anyone who belongs to their school
--   * teachers: learners they teach, and those learners' parents
--   * parents: their children, and their children's teachers
--   * students: their teachers and their own parents (not classmates)
create function private.can_view_profile(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_profile_id = (select private.current_profile_id())
    -- school admins: members of their school
    or exists (
      select 1 from public.school_memberships m
      where m.profile_id = p_profile_id and private.is_school_admin(m.school_id)
    )
    -- teachers: learners they teach
    or private.teaches_student(p_profile_id)
    -- teachers: parents of learners they teach
    or exists (
      select 1 from public.guardianships g
      where g.parent_profile_id = p_profile_id and private.teaches_student(g.student_profile_id)
    )
    -- parents: their children
    or private.is_parent_of(p_profile_id)
    -- parents and students: teachers of classes they can see as a learner or parent
    or exists (
      select 1
      from public.teaching_allocations ta
      join public.class_subjects cs on cs.id = ta.class_subject_id
      where ta.teacher_profile_id = p_profile_id
        and (private.is_enrolled_in(cs.class_id) or private.is_parent_in_class(cs.class_id))
    )
    -- students: their own parents
    or exists (
      select 1
      from public.guardianships g
      join public.school_memberships m
        on m.school_id = g.school_id
       and m.profile_id = g.student_profile_id
       and m.role = 'student'
       and m.status = 'active'
      where g.parent_profile_id = p_profile_id
        and g.student_profile_id = (select private.current_profile_id())
    )
$$;

-- Policies run as the signed-in user, so they need to be able to call these helpers.
-- The private schema is never exposed through the Data API, so they can't be called
-- directly from an app.
revoke execute on all functions in schema private from public;
grant execute on function
  private.current_profile_id(),
  private.has_role(uuid, public.membership_role),
  private.is_member(uuid),
  private.is_school_admin(uuid),
  private.teaches_class(uuid),
  private.is_enrolled_in(uuid),
  private.is_parent_of(uuid),
  private.is_parent_in_class(uuid),
  private.teaches_student(uuid),
  private.can_view_class(uuid),
  private.can_view_class_subject(uuid),
  private.can_view_profile(uuid)
to authenticated;

-- Everything the staff dashboard needs for the signed-in teacher or school admin, in
-- one call: who they are, their school and current year, their roles there, and the
-- subjects they teach this year with learner and onboarding counts.
--
-- The dashboard used to ask for this in six separate requests, one after another,
-- on every page. One call is one round trip.
--
-- security invoker: it runs as the signed-in person, so every table's row-level
-- security still decides what they can see. It adds no access of its own.
--
-- Returns null if the signed-in person isn't an active teacher or school admin.
-- Someone on staff at more than one school gets one school for now (a school where
-- they teach first); a school switcher comes later.

create function public.my_staff_dashboard()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with me as (
    select p.id, p.full_name, p.preferred_name
    from public.profiles p
    where p.user_id = (select auth.uid())
  ),
  staff_roles as (
    select m.school_id, m.role
    from public.school_memberships m
    join me on m.profile_id = me.id
    where m.status = 'active'
      and m.role in ('teacher', 'school_admin')
  ),
  school as (
    select s.id, s.name
    from public.schools s
    where s.id in (select r.school_id from staff_roles r)
    order by
      exists (
        select 1 from staff_roles r where r.school_id = s.id and r.role = 'teacher'
      ) desc,
      s.name,
      s.id
    limit 1
  ),
  current_year as (
    select y.id, y.label
    from public.academic_years y
    join school on y.school_id = school.id
    where y.is_current
  ),
  taught as (
    select
      cs.id as class_subject_id,
      c.id as class_id,
      c.name as class_name,
      c.grade,
      sub.name as subject_name,
      (select count(*) from public.enrolments e where e.class_id = c.id) as learners,
      (
        select count(*)
        from public.enrolments e
        join public.student_study_profiles sp
          on sp.student_profile_id = e.student_profile_id
         and sp.academic_year_id = c.academic_year_id
        where e.class_id = c.id
          and sp.onboarding_completed_at is not null
      ) as onboarded
    from public.teaching_allocations ta
    join me on ta.teacher_profile_id = me.id
    join public.class_subjects cs on cs.id = ta.class_subject_id
    join public.classes c on c.id = cs.class_id
    join current_year y on c.academic_year_id = y.id
    join public.subjects sub on sub.id = cs.subject_id
  )
  select jsonb_build_object(
    'profile_id', me.id,
    'full_name', me.full_name,
    'preferred_name', me.preferred_name,
    'school_id', school.id,
    'school_name', school.name,
    'roles', (
      select jsonb_agg(r.role order by r.role)
      from staff_roles r
      where r.school_id = school.id
    ),
    'year_label', (select y.label from current_year y),
    'classes', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'class_subject_id', t.class_subject_id,
            'class_id', t.class_id,
            'class_name', t.class_name,
            'grade', t.grade,
            'subject_name', t.subject_name,
            'learners', t.learners,
            'onboarded', t.onboarded
          )
          order by t.grade, t.class_name, t.subject_name
        )
        from taught t
      ),
      '[]'::jsonb
    )
  )
  from me
  cross join school
$$;

comment on function public.my_staff_dashboard() is
  'The signed-in staff member''s dashboard: school, year, roles and classes taught. Null if not staff. Runs under row-level security.';

revoke execute on function public.my_staff_dashboard() from public, anon;
grant execute on function public.my_staff_dashboard() to authenticated;

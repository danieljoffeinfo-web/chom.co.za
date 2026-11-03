-- Everything the learner's home and onboarding need for the signed-in student, in
-- one call: who they are, their school and current year, their classes and subjects,
-- and any study habits and goals already saved.
--
-- Those screens used to ask for this in several requests, one after another. One
-- call is one round trip.
--
-- security invoker: it runs as the signed-in person, so every table's row-level
-- security still decides what they can see. It adds no access of its own.
--
-- Returns null if the signed-in person isn't an active student with a current year.
-- A student at more than one school gets one school for now (the first by name);
-- a school switcher comes later.

create function public.my_student_dashboard()
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
  membership as (
    select m.school_id, s.name as school_name
    from public.school_memberships m
    join me on m.profile_id = me.id
    join public.schools s on s.id = m.school_id
    where m.role = 'student'
      and m.status = 'active'
    order by s.name, m.school_id
    limit 1
  ),
  current_year as (
    select y.id, y.label
    from public.academic_years y
    join membership on y.school_id = membership.school_id
    where y.is_current
  ),
  enrolled as (
    select c.id as class_id, c.name as class_name, c.grade
    from public.enrolments e
    join me on e.student_profile_id = me.id
    join public.classes c on c.id = e.class_id
    join current_year y on c.academic_year_id = y.id
  ),
  taken as (
    select
      sub.id,
      sub.name,
      cur.category,
      coalesce(cur.sort_order, 1000) as sort_order
    from enrolled en
    join public.class_subjects cs on cs.class_id = en.class_id
    join public.subjects sub on sub.id = cs.subject_id
    left join public.curriculum_subjects cur on cur.id = sub.curriculum_subject_id
    group by sub.id, sub.name, cur.category, cur.sort_order
  )
  select jsonb_build_object(
    'profile_id', me.id,
    'full_name', me.full_name,
    'preferred_name', me.preferred_name,
    'school_id', membership.school_id,
    'school_name', membership.school_name,
    'academic_year_id', current_year.id,
    'year_label', current_year.label,
    'grade', (select en.grade from enrolled en order by en.class_name limit 1),
    'class_names', coalesce(
      (select jsonb_agg(en.class_name order by en.class_name) from enrolled en),
      '[]'::jsonb
    ),
    'subjects', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'category', t.category,
            'sort_order', t.sort_order
          )
          order by t.sort_order, t.name
        )
        from taken t
      ),
      '[]'::jsonb
    ),
    'study_profile', (
      select to_jsonb(sp)
      from public.student_study_profiles sp
      where sp.student_profile_id = me.id
        and sp.academic_year_id = current_year.id
    ),
    'goals', coalesce(
      (
        select jsonb_agg(to_jsonb(g) order by g.subject_id)
        from public.student_subject_goals g
        where g.student_profile_id = me.id
          and g.academic_year_id = current_year.id
      ),
      '[]'::jsonb
    )
  )
  from me
  cross join membership
  cross join current_year
$$;

comment on function public.my_student_dashboard() is
  'The signed-in student''s home and onboarding: school, year, classes, subjects, study habits and goals. Null if not a student. Runs under row-level security.';

revoke execute on function public.my_student_dashboard() from public, anon;
grant execute on function public.my_student_dashboard() to authenticated;

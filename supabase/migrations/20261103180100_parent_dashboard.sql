-- Everything the parent dashboard needs for the signed-in parent, in one call: who
-- they are, and each child they may see (active link, current consent), with the
-- child's school, current year, grade, classes, subjects and teachers, and the study
-- habits and goals the child set at onboarding.
--
-- security invoker: it runs as the signed-in parent, so every table's row-level
-- security decides what comes back. It adds no access. Each link must also be active,
-- held through an active parent membership, and consented to the current version
-- itself: a parent who can see the child another way (as their teacher, say) still
-- doesn't get the parent dashboard for that link without consent, nor while they are
-- blocked from the child at another school.
--
-- Children are returned across schools (a parent with children at two campuses gets
-- both). Returns null if the signed-in person has no profile.

create function public.my_parent_dashboard()
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
  links as (
    select g.id, g.school_id, g.student_profile_id, g.relationship, g.is_primary
    from public.guardianships g
    join me on g.parent_profile_id = me.id
    where g.status = 'active'
      and private.has_role(g.school_id, 'parent')
      -- Also no block on this child at any school.
      and private.is_parent_of(g.student_profile_id)
      and exists (
        select 1 from public.parent_consents pc
        where pc.guardianship_id = g.id
          and pc.parent_profile_id = g.parent_profile_id
          and pc.student_profile_id = g.student_profile_id
          and pc.consent_version = (select private.current_parent_consent_version())
          and pc.withdrawn_at is null
      )
  ),
  children as (
    select
      l.id as guardianship_id,
      l.relationship,
      l.is_primary,
      child.id as profile_id,
      child.full_name,
      child.preferred_name,
      s.id as school_id,
      s.name as school_name,
      y.id as year_id,
      y.label as year_label
    from links l
    -- RLS still applies to the child's profile (a block at another school hides it).
    join public.profiles child on child.id = l.student_profile_id
    join public.schools s on s.id = l.school_id
    left join public.academic_years y on y.school_id = l.school_id and y.is_current
  )
  select jsonb_build_object(
    'profile_id', me.id,
    'full_name', me.full_name,
    'preferred_name', me.preferred_name,
    'children', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'guardianship_id', c.guardianship_id,
            'profile_id', c.profile_id,
            'full_name', c.full_name,
            'preferred_name', c.preferred_name,
            'relationship', c.relationship,
            'is_primary', c.is_primary,
            'school_id', c.school_id,
            'school_name', c.school_name,
            'year_label', c.year_label,
            'grade', (
              select min(cl.grade)
              from public.enrolments e
              join public.classes cl on cl.id = e.class_id
              where e.student_profile_id = c.profile_id and cl.academic_year_id = c.year_id
            ),
            'classes', coalesce(
              (
                select jsonb_agg(cl.name order by cl.grade, cl.name)
                from public.enrolments e
                join public.classes cl on cl.id = e.class_id
                where e.student_profile_id = c.profile_id and cl.academic_year_id = c.year_id
              ),
              '[]'::jsonb
            ),
            'study', (
              select jsonb_build_object(
                'onboarding_completed_at', sp.onboarding_completed_at,
                'session_length', sp.session_length,
                'study_methods', to_jsonb(sp.study_methods),
                'study_times', to_jsonb(sp.study_times)
              )
              from public.student_study_profiles sp
              where sp.student_profile_id = c.profile_id and sp.academic_year_id = c.year_id
            ),
            'subjects', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'subject_id', sub.id,
                    'name', sub.name,
                    'category', cur.category,
                    'teachers', sub.teachers,
                    'target_percent', goal.target_percent,
                    'is_focus', coalesce(goal.is_focus, false)
                  )
                  order by coalesce(cur.sort_order, 1000), sub.name
                )
                from (
                  select
                    su.id,
                    su.name,
                    su.curriculum_subject_id,
                    coalesce(
                      jsonb_agg(distinct coalesce(tp.preferred_name, tp.full_name))
                        filter (where tp.id is not null),
                      '[]'::jsonb
                    ) as teachers
                  from public.enrolments e
                  join public.classes cl on cl.id = e.class_id
                  join public.class_subjects cs on cs.class_id = cl.id
                  join public.subjects su on su.id = cs.subject_id
                  left join public.teaching_allocations ta on ta.class_subject_id = cs.id
                  left join public.profiles tp on tp.id = ta.teacher_profile_id
                  where e.student_profile_id = c.profile_id and cl.academic_year_id = c.year_id
                  group by su.id, su.name, su.curriculum_subject_id
                ) sub
                left join public.curriculum_subjects cur on cur.id = sub.curriculum_subject_id
                left join public.student_subject_goals goal
                  on goal.student_profile_id = c.profile_id
                 and goal.academic_year_id = c.year_id
                 and goal.subject_id = sub.id
              ),
              '[]'::jsonb
            )
          )
          order by coalesce(c.preferred_name, c.full_name), c.school_name
        )
        from children c
      ),
      '[]'::jsonb
    )
  )
  from me
$$;

comment on function public.my_parent_dashboard() is
  'The signed-in parent''s dashboard: each consented child with school, classes, subjects, teachers and goals. Runs under row-level security.';

revoke execute on function public.my_parent_dashboard() from public, anon;
grant execute on function public.my_parent_dashboard() to authenticated;

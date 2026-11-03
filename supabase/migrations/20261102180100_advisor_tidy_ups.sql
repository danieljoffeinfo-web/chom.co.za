-- Tidy-ups from the Supabase security and performance advisors on production.

-- 1. Supabase's "Enable automatic RLS" setting creates public.rls_auto_enable(), an
--    event-trigger function that app users could otherwise call through the API. It
--    only needs to run as an event trigger, which doesn't depend on EXECUTE grants.
--    It doesn't exist in local or CI databases, hence the existence check.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;

-- 2. Indexes that exactly match each composite foreign key (the ones that include
--    school_id), so deletes and joins on them never scan.
create index if not exists class_subjects_class_id_school_id_idx
  on public.class_subjects (class_id, school_id);
create index if not exists class_subjects_subject_id_school_id_idx
  on public.class_subjects (subject_id, school_id);
create index if not exists classes_academic_year_id_school_id_idx
  on public.classes (academic_year_id, school_id);
create index if not exists enrolments_class_id_school_id_idx
  on public.enrolments (class_id, school_id);
create index if not exists enrolments_school_student_role_idx
  on public.enrolments (school_id, student_profile_id, student_role);
create index if not exists guardianships_school_parent_role_idx
  on public.guardianships (school_id, parent_profile_id, parent_role);
create index if not exists guardianships_school_student_role_idx
  on public.guardianships (school_id, student_profile_id, student_role);
create index if not exists teaching_allocations_class_subject_id_school_id_idx
  on public.teaching_allocations (class_subject_id, school_id);
create index if not exists teaching_allocations_school_teacher_role_idx
  on public.teaching_allocations (school_id, teacher_profile_id, teacher_role);

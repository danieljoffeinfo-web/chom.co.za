-- Styfe: Chom's demo school on styfe.co.za. Run once on production, by hand, after
-- migration 20261111180000_email_code_sign_in has deployed. It is not a migration, so
-- the test databases never get it.
--
-- The school is recognised by its domain, and everyone signs in with an emailed code.
-- The roster decides who each person is, so nobody picks a school or types details:
--   dan@styfe.co.za     student, Grade 10, class 10D
--   david@styfe.co.za   Dan's parent (asked for POPIA consent on first sign-in)
--   tanya@styfe.co.za   teacher of all seven 10D subjects
-- Names are first names only. Each person types their full name on first sign-in.
--
-- Refuses to run twice: it stops if a school called styfe already exists.

do $$
declare
  v_curriculum uuid;
  v_group uuid;
  v_school uuid;
  v_year uuid;
  v_class uuid;
  v_dan uuid;
  v_david uuid;
  v_tanya uuid;
  v_subject uuid;
  v_class_subject uuid;
  r record;
begin
  if exists (select 1 from public.schools where slug = 'styfe') then
    raise exception 'Styfe is already loaded';
  end if;

  select id into v_curriculum from public.curricula where code = 'IEB';
  if v_curriculum is null then
    raise exception 'The IEB curriculum is missing';
  end if;

  -- The school, its domain and its year ------------------------------------------

  insert into public.school_groups (name, slug) values ('Styfe', 'styfe') returning id into v_group;
  insert into public.school_group_domains (school_group_id, domain, provider)
  values (v_group, 'styfe.co.za', 'email_code');
  insert into public.schools (name, slug, school_group_id)
  values ('Styfe', 'styfe', v_group) returning id into v_school;

  insert into public.academic_years (school_id, label, starts_on, ends_on, curriculum_id, is_current)
  values (v_school, '2026', '2026-01-14', '2026-12-09', v_curriculum, true)
  returning id into v_year;

  -- 2026 terms (the national school calendar). Change them if Styfe's differ.
  insert into public.school_terms (school_id, academic_year_id, term_number, starts_on, ends_on) values
    (v_school, v_year, 1, '2026-01-14', '2026-03-27'),
    (v_school, v_year, 2, '2026-04-08', '2026-06-26'),
    (v_school, v_year, 3, '2026-07-21', '2026-10-02'),
    (v_school, v_year, 4, '2026-10-13', '2026-12-09');

  -- People ----------------------------------------------------------------------

  insert into public.profiles (full_name) values ('Dan') returning id into v_dan;
  insert into public.profiles (full_name) values ('David') returning id into v_david;
  insert into public.profiles (full_name) values ('Tanya') returning id into v_tanya;

  insert into public.school_memberships (school_id, profile_id, role, email, job_title) values
    (v_school, v_dan, 'student', 'dan@styfe.co.za', null),
    (v_school, v_david, 'parent', 'david@styfe.co.za', null),
    (v_school, v_tanya, 'teacher', 'tanya@styfe.co.za', 'Teacher');

  insert into public.guardianships (school_id, parent_profile_id, student_profile_id, relationship, status, is_primary, invited_at)
  values (v_school, v_david, v_dan, 'guardian', 'invited', true, now());

  -- Class 10D ------------------------------------------------------------------

  insert into public.classes (school_id, academic_year_id, grade, name, kind)
  values (v_school, v_year, 10, '10D', 'register') returning id into v_class;

  insert into public.enrolments (school_id, class_id, student_profile_id)
  values (v_school, v_class, v_dan);

  -- Subjects: what Styfe offers, and 10D's seven. Tanya teaches every one for now;
  -- a real school gives each class subject its own teacher(s).

  for r in
    select * from (values
      ('English Home Language', 'fundamental'::public.offering_kind, null::text),
      ('Afrikaans First Additional Language', 'fundamental', null),
      ('Mathematical Literacy', 'fundamental', null),
      ('Life Orientation', 'fundamental', null),
      ('Business Studies', 'elective', 'A'),
      ('Dramatic Arts', 'elective', 'B'),
      ('Life Sciences', 'elective', 'C')
    ) as s (name, kind, block)
  loop
    insert into public.subjects (school_id, name, curriculum_subject_id)
    select v_school, cs.name, cs.id
    from public.curriculum_subjects cs
    where cs.curriculum_id = v_curriculum and cs.name = r.name
    returning id into v_subject;
    if v_subject is null then
      raise exception 'Catalogue subject % is missing', r.name;
    end if;

    insert into public.subject_offerings (school_id, academic_year_id, subject_id, kind, block, min_grade, max_grade)
    values (v_school, v_year, v_subject, r.kind, r.block, 10, 12);

    insert into public.class_subjects (school_id, class_id, subject_id)
    values (v_school, v_class, v_subject) returning id into v_class_subject;

    insert into public.teaching_allocations (school_id, class_subject_id, teacher_profile_id)
    values (v_school, v_class_subject, v_tanya);

    v_subject := null;
  end loop;

  -- Lay the Grade 10 units over Styfe's 2026 terms.
  perform private.generate_unit_schedule(v_year);
end;
$$;

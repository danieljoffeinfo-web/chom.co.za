-- Row-level security: who can see and change what.
--
-- Plain-English rules (also tested in supabase/tests):
--   * Nobody sees anything from a school they don't belong to.
--   * Students: their own details, their school's subjects, the classes they're in.
--     Not their classmates.
--   * Teachers: classes they teach, the learners in them, and those learners' parents.
--   * Parents: their own children, and those children's classes and teachers.
--   * School admins: everything in their own school, and they manage it.
--   * Everyone can change their own preferred name. All other changes in this
--     migration are school admins only (and, later, the Ednana sync and admin
--     dashboard, which run on the server).
--
-- Signed-out visitors (anon) can reach nothing.

-- ---------------------------------------------------------------------------------
-- Open tables to signed-in users. Row-level security decides which rows.
-- ---------------------------------------------------------------------------------

select private.expose_table('public.curricula', 'select');
select private.expose_table('public.curriculum_subjects', 'select');
select private.expose_table('public.schools', 'select');
select private.expose_table('public.academic_years', 'select, insert, update, delete');
select private.expose_table('public.profiles', 'select');
select private.expose_table('public.school_memberships', 'select, insert, delete');
select private.expose_table('public.guardianships', 'select, insert, update, delete');
select private.expose_table('public.subjects', 'select, insert, update, delete');
select private.expose_table('public.classes', 'select, insert, update, delete');
select private.expose_table('public.class_subjects', 'select, insert, update, delete');
select private.expose_table('public.teaching_allocations', 'select, insert, update, delete');
select private.expose_table('public.enrolments', 'select, insert, update, delete');

-- Column-level: people may change only their preferred name; their full name comes
-- from the school. Admins may change only a membership's status and Ednana id, never
-- who it belongs to or which role it is.
grant update (preferred_name) on public.profiles to authenticated;
grant update (status, ednana_id) on public.school_memberships to authenticated;

-- ---------------------------------------------------------------------------------
-- Reference data: readable by every signed-in user, changed only by migrations.
-- ---------------------------------------------------------------------------------

create policy "Signed-in users can read curricula"
  on public.curricula for select to authenticated
  using (true);

create policy "Signed-in users can read curriculum subjects"
  on public.curriculum_subjects for select to authenticated
  using (true);

-- ---------------------------------------------------------------------------------
-- Schools and years
-- ---------------------------------------------------------------------------------

create policy "Members can read their schools"
  on public.schools for select to authenticated
  using (private.is_member(id));

create policy "Members can read their school's years"
  on public.academic_years for select to authenticated
  using (private.is_member(school_id));

create policy "School admins can add years"
  on public.academic_years for insert to authenticated
  with check (private.is_school_admin(school_id));

create policy "School admins can change years"
  on public.academic_years for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));

create policy "School admins can remove years"
  on public.academic_years for delete to authenticated
  using (private.is_school_admin(school_id));

-- ---------------------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------------------

create policy "People can read profiles they are allowed to see"
  on public.profiles for select to authenticated
  using (private.can_view_profile(id));

create policy "People can change their own preferred name"
  on public.profiles for update to authenticated
  using (id = (select private.current_profile_id()))
  with check (id = (select private.current_profile_id()));

create policy "Own memberships, or all of it for school admins"
  on public.school_memberships for select to authenticated
  using (
    profile_id = (select private.current_profile_id())
    or private.is_school_admin(school_id)
  );

create policy "School admins can add memberships"
  on public.school_memberships for insert to authenticated
  with check (private.is_school_admin(school_id));

create policy "School admins can change memberships"
  on public.school_memberships for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));

create policy "School admins can remove memberships"
  on public.school_memberships for delete to authenticated
  using (private.is_school_admin(school_id));

create policy "Visible to admins, the parent, the child and their teachers"
  on public.guardianships for select to authenticated
  using (
    private.is_school_admin(school_id)
    or (
      parent_profile_id = (select private.current_profile_id())
      and private.has_role(school_id, 'parent')
    )
    or (
      student_profile_id = (select private.current_profile_id())
      and private.has_role(school_id, 'student')
    )
    or private.teaches_student(student_profile_id)
  );

create policy "School admins can add guardianships"
  on public.guardianships for insert to authenticated
  with check (private.is_school_admin(school_id));

create policy "School admins can change guardianships"
  on public.guardianships for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));

create policy "School admins can remove guardianships"
  on public.guardianships for delete to authenticated
  using (private.is_school_admin(school_id));

-- ---------------------------------------------------------------------------------
-- Subjects, classes, teaching and enrolment
-- ---------------------------------------------------------------------------------

create policy "Members can read their school's subjects"
  on public.subjects for select to authenticated
  using (private.is_member(school_id));

create policy "School admins can add subjects"
  on public.subjects for insert to authenticated
  with check (private.is_school_admin(school_id));

create policy "School admins can change subjects"
  on public.subjects for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));

create policy "School admins can remove subjects"
  on public.subjects for delete to authenticated
  using (private.is_school_admin(school_id));

create policy "Visible to admins, its teachers, learners and their parents"
  on public.classes for select to authenticated
  using (private.can_view_class(id));

create policy "School admins can add classes"
  on public.classes for insert to authenticated
  with check (private.is_school_admin(school_id));

create policy "School admins can change classes"
  on public.classes for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));

create policy "School admins can remove classes"
  on public.classes for delete to authenticated
  using (private.is_school_admin(school_id));

create policy "Class subjects are visible to whoever can see the class"
  on public.class_subjects for select to authenticated
  using (private.can_view_class(class_id));

create policy "School admins can add class subjects"
  on public.class_subjects for insert to authenticated
  with check (private.is_school_admin(school_id));

create policy "School admins can change class subjects"
  on public.class_subjects for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));

create policy "School admins can remove class subjects"
  on public.class_subjects for delete to authenticated
  using (private.is_school_admin(school_id));

create policy "Teaching allocations are visible to whoever can see the class"
  on public.teaching_allocations for select to authenticated
  using (private.can_view_class_subject(class_subject_id));

create policy "School admins can add teaching allocations"
  on public.teaching_allocations for insert to authenticated
  with check (private.is_school_admin(school_id));

create policy "School admins can change teaching allocations"
  on public.teaching_allocations for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));

create policy "School admins can remove teaching allocations"
  on public.teaching_allocations for delete to authenticated
  using (private.is_school_admin(school_id));

-- Students see only their own enrolment rows, so they can't list their classmates.
create policy "Visible to admins, the class teachers, the learner and parents"
  on public.enrolments for select to authenticated
  using (
    private.is_school_admin(school_id)
    or private.teaches_class(class_id)
    or (
      student_profile_id = (select private.current_profile_id())
      and private.has_role(school_id, 'student')
    )
    or private.is_parent_of(student_profile_id)
  );

create policy "School admins can add enrolments"
  on public.enrolments for insert to authenticated
  with check (private.is_school_admin(school_id));

create policy "School admins can change enrolments"
  on public.enrolments for update to authenticated
  using (private.is_school_admin(school_id))
  with check (private.is_school_admin(school_id));

create policy "School admins can remove enrolments"
  on public.enrolments for delete to authenticated
  using (private.is_school_admin(school_id));

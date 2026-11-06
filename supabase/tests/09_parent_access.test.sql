-- Parent links, consent and the parent dashboard (docs/design/parent-dashboard.md §2, §3).
--
-- Acceptance criteria covered:
--   * A parent cannot see any learner data before consent is recorded
--   * A blocked guardian sees nothing for that learner, even by asking directly
--   * A cross-school guardian sees only their own learners in each school
-- Plus: withdrawing consent, a new consent version, and who may change links.
-- Also: a block applies to the child at every school, only admins can read why a link
-- was blocked, moving a link voids its consent, the dashboard checks consent per link
-- even for a parent who also teaches the child, consent is never recorded twice, and
-- a blocked link can't be moved.
--
-- Seed: Ngozi (07) is Amara's mother at Demo High and Kai's guardian at Other College.
-- Lerato (17) is Kai's mother. Every seeded parent has consented to 2026-11-draft-1.

begin;
create extension if not exists pgtap with schema extensions;

select plan(67);

-- Amara has onboarded, so there is study data to hide or show.
insert into public.student_study_profiles
  (school_id, academic_year_id, student_profile_id, session_length, study_methods, study_times,
   onboarding_completed_at)
values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '40000000-0000-4000-8000-000000000004', 'minutes_45', '{past_papers}', '{evening}', now());
insert into public.student_subject_goals
  (school_id, academic_year_id, student_profile_id, subject_id, is_focus, target_percent)
values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '40000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000001', true, 75);

-- Ngozi starts as a freshly invited parent: no consent yet.
delete from public.parent_consents where parent_profile_id = '40000000-0000-4000-8000-000000000007';
update public.guardianships set status = 'invited', activated_at = null
where parent_profile_id = '40000000-0000-4000-8000-000000000007';

-- ---------------------------------------------------------------------------------
-- Before consent: names on the consent screen, no child data
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from public.my_guardian_links()), 2, 'Invited: both children are listed for the consent screen');
select is((select count(*)::int from public.my_guardian_links() where consented), 0, 'Invited: neither child is consented yet');
select is(
  (select jsonb_agg(student_name order by student_name) from public.my_guardian_links()),
  '["Amara Nwosu", "Kai Naidoo"]'::jsonb,
  'Invited: the consent screen gets each child''s name'
);
select is((select count(*)::int from public.profiles where id <> '40000000-0000-4000-8000-000000000007'), 0, 'Invited: sees no one''s profile but her own');
select is((select count(*)::int from public.enrolments), 0, 'Invited: sees no enrolments');
select is((select count(*)::int from public.classes), 0, 'Invited: sees no classes');
select is((select count(*)::int from public.student_study_profiles), 0, 'Invited: sees no study habits');
select is((select count(*)::int from public.student_subject_goals), 0, 'Invited: sees no goals');
select is(jsonb_array_length(public.my_parent_dashboard() -> 'children'), 0, 'Invited: the dashboard has no children');

select throws_ok(
  $$ select public.record_parent_consent('2025-01-old', true, true, false) $$,
  '22023', 'That consent version is not the current one',
  'Consent to anything but the current version is refused'
);
select throws_ok(
  $$ insert into public.parent_consents (school_id, guardianship_id, parent_profile_id, student_profile_id, consent_version)
     select school_id, id, parent_profile_id, student_profile_id, '2026-11-draft-1'
     from public.guardianships where parent_profile_id = '40000000-0000-4000-8000-000000000007' $$,
  '42501', null,
  'A parent cannot write a consent row directly'
);

-- ---------------------------------------------------------------------------------
-- Consent
-- ---------------------------------------------------------------------------------

select is(
  public.record_parent_consent('2026-11-draft-1', true, true, false, '196.25.1.1', 'Test browser'),
  2,
  'Consent covers both children'
);
select is((select count(*)::int from public.my_guardian_links() where consented and status = 'active'), 2, 'Both links are now active and consented');
select is((select count(*)::int from public.enrolments), 2, 'Consented: sees both children''s enrolments');
select is((select count(*)::int from public.student_study_profiles), 1, 'Consented: sees Amara''s study habits');
select is(
  (select jsonb_agg(c ->> 'full_name') from jsonb_array_elements(public.my_parent_dashboard() -> 'children') c),
  '["Amara Nwosu", "Kai Naidoo"]'::jsonb,
  'Consented: the dashboard has both children, across both schools'
);
select is(
  (select jsonb_agg(c ->> 'school_name') from jsonb_array_elements(public.my_parent_dashboard() -> 'children') c),
  '["Demo High School", "Other College"]'::jsonb,
  'Each child comes with their own school'
);
select is(
  (
    select s - 'subject_id'
    from jsonb_array_elements(public.my_parent_dashboard() -> 'children' -> 0 -> 'subjects') s
    where s ->> 'name' = 'Mathematics'
  ),
  '{"name":"Mathematics","category":null,"teachers":["Sizwe Dlamini"],"is_focus":true,"target_percent":75}'::jsonb,
  'A subject comes with its teacher and the child''s target and focus'
);
select is(
  public.my_parent_dashboard() -> 'children' -> 0 -> 'study' ->> 'session_length', 'minutes_45',
  'The dashboard includes the child''s study habits'
);
select is(
  (select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000005'), 0,
  'Consented: still cannot see Liam, Amara''s classmate'
);
select is(
  (select count(*)::int from public.guardianships where parent_profile_id <> '40000000-0000-4000-8000-000000000007'), 0,
  'Cross-school: does not see Lerato''s link to Kai'
);
select is(
  (select (whatsapp, email, push)::text from public.parent_notification_channels), '(t,t,f)',
  'Her channel choices from the consent screen are saved'
);
select is(
  (select ip::text from public.parent_consents where student_profile_id = '40000000-0000-4000-8000-000000000004'),
  '196.25.1.1/32',
  'The consent records where it was given from'
);
select throws_ok(
  $$ insert into public.parent_notification_channels (profile_id) values ('40000000-0000-4000-8000-000000000017') $$,
  '42501', null,
  'A parent cannot set another person''s channels'
);
reset role;

-- ---------------------------------------------------------------------------------
-- A block covers the child at every school
-- ---------------------------------------------------------------------------------

-- Kai is also enrolled at Demo High, where Ngozi's link to him is blocked. Her
-- consented link at Other College must not let her see him.
insert into public.school_memberships (school_id, profile_id, role, email) values
  ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000014', 'student', 'kai.naidoo@demo-high.test');
insert into public.guardianships (school_id, parent_profile_id, student_profile_id, relationship, status, blocked_reason) values
  ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000007', '40000000-0000-4000-8000-000000000014', 'guardian', 'blocked', 'Court order 2026/200');

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000014'), 0, 'Blocked at one school: cannot see Kai, even through the other school''s link');
select is((select count(*)::int from public.enrolments), 1, 'Blocked at one school: sees only Amara''s enrolment');
select is(
  (select jsonb_agg(c ->> 'full_name') from jsonb_array_elements(public.my_parent_dashboard() -> 'children') c),
  '["Amara Nwosu"]'::jsonb,
  'Blocked at one school: Kai is not on her dashboard'
);
reset role;

delete from public.guardianships
where school_id = '10000000-0000-4000-8000-000000000001' and student_profile_id = '40000000-0000-4000-8000-000000000014';
delete from public.school_memberships
where school_id = '10000000-0000-4000-8000-000000000001' and profile_id = '40000000-0000-4000-8000-000000000014';

-- ---------------------------------------------------------------------------------
-- Blocking (school admin)
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000011","role":"authenticated"}', true);
set local role authenticated;
with u as (
  update public.guardianships set status = 'blocked', blocked_reason = 'Court order'
  where student_profile_id = '40000000-0000-4000-8000-000000000004' returning 1
)
select is(count(*)::int, 0, 'Another school''s admin cannot block a Demo High link') from u;
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$ update public.guardianships set status = 'blocked'
     where parent_profile_id = '40000000-0000-4000-8000-000000000007' $$,
  '23514', null,
  'Blocking needs a reason'
);
with u as (
  update public.guardianships set status = 'blocked', blocked_reason = 'Court order 2026/114'
  where parent_profile_id = '40000000-0000-4000-8000-000000000007' returning 1
)
select is(count(*)::int, 1, 'Demo High''s admin blocks Ngozi from Amara (only the Demo High link is hers to change)') from u;
select isnt(
  (select blocked_at from public.guardianships where student_profile_id = '40000000-0000-4000-8000-000000000004'
     and parent_profile_id = '40000000-0000-4000-8000-000000000007'),
  null,
  'The time of the block is recorded'
);
select is(
  (select count(*)::int from public.parent_consents where school_id = '10000000-0000-4000-8000-000000000001'), 3,
  'The admin can see consents for her school'
);
reset role;

-- Amara can see that the link is blocked, but not why.
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.guardianships where status = 'blocked'), 1, 'The child sees that a link is blocked');
select throws_ok(
  $$ select blocked_reason from public.guardianships $$,
  '42501', null,
  'The child cannot read why the link was blocked'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;
select is(
  (select jsonb_agg(student_name) from public.my_guardian_links()), '["Kai Naidoo"]'::jsonb,
  'Blocked: Amara is gone from her list of children'
);
select is((select count(*)::int from public.guardianships where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'Blocked: she cannot see the blocked link itself');
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000004'), 0, 'Blocked: cannot read Amara''s profile directly');
select is((select count(*)::int from public.student_study_profiles), 0, 'Blocked: cannot read Amara''s study habits directly');
select is((select count(*)::int from public.parent_consents where school_id = '10000000-0000-4000-8000-000000000001'), 0, 'Blocked: cannot see her consent for Amara');
select is(
  (select jsonb_agg(c ->> 'full_name') from jsonb_array_elements(public.my_parent_dashboard() -> 'children') c),
  '["Kai Naidoo"]'::jsonb,
  'Blocked: the dashboard has only Kai'
);
select is(public.record_parent_consent('2026-11-draft-1', true, true, false), 1, 'Consenting again does not unblock Amara');
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is(
  (select status::text from public.guardianships
   where parent_profile_id = '40000000-0000-4000-8000-000000000007'
     and student_profile_id = '40000000-0000-4000-8000-000000000004'),
  'blocked',
  'After consenting again, the admin still sees Amara''s link as blocked'
);
select throws_ok(
  $$ update public.guardianships set parent_profile_id = '40000000-0000-4000-8000-000000000008'
     where parent_profile_id = '40000000-0000-4000-8000-000000000007'
       and student_profile_id = '40000000-0000-4000-8000-000000000004' $$,
  '22023', 'A blocked link cannot be moved to another parent, child or school',
  'A blocked link cannot be moved to another parent'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;

-- ---------------------------------------------------------------------------------
-- Withdrawing consent, and a new consent version
-- ---------------------------------------------------------------------------------

select public.withdraw_parent_consent(
  (select guardianship_id from public.my_guardian_links() where student_name = 'Kai Naidoo')
);
select is(
  (select status::text from public.my_guardian_links()), 'consent_withdrawn',
  'Withdrawn: the link to Kai is marked as withdrawn'
);
select is((select count(*)::int from public.enrolments), 0, 'Withdrawn: sees nothing about Kai');
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000017","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.enrolments), 1, 'Lerato, Kai''s other parent, still sees him');
reset role;

-- Ngozi tries to withdraw Lerato's active link (its id read here, outside RLS).
select set_config('test.lerato_link',
  (select id::text from public.guardianships where parent_profile_id = '40000000-0000-4000-8000-000000000017'), true);
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$ select public.withdraw_parent_consent(current_setting('test.lerato_link')::uuid) $$,
  '22023', 'No active link to withdraw',
  'A parent cannot withdraw another parent''s consent'
);
reset role;
select is(
  (select status::text from public.guardianships where parent_profile_id = '40000000-0000-4000-8000-000000000017'), 'active',
  'Lerato''s link is still active'
);

-- A new version of the consent text: everyone must consent again.
insert into public.parent_consent_versions (version, published_at) values ('2026-12-v2', now() - interval '1 minute');

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000017","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.enrolments), 0, 'New consent version: Lerato sees nothing until she consents again');
select is(public.record_parent_consent('2026-12-v2', false, true, false), 1, 'Lerato consents to the new version');
select is((select count(*)::int from public.enrolments), 1, 'And sees Kai again');
select public.record_parent_consent('2026-12-v2', false, true, false);
select is(
  (select count(*)::int from public.parent_consents where consent_version = '2026-12-v2' and withdrawn_at is null), 1,
  'Consenting twice records one consent, not two'
);
reset role;

-- ---------------------------------------------------------------------------------
-- A parent who also teaches the child: the dashboard still needs consent
-- ---------------------------------------------------------------------------------

-- Sizwe (02) is Zoe's father. Here he also teaches her class, so he can see her as a
-- teacher. His consent is for the old version.
insert into public.teaching_allocations (school_id, class_subject_id, teacher_profile_id) values
  ('10000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000002');

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000006'), 1, 'Sizwe sees Zoe as her teacher');
select is(jsonb_array_length(public.my_parent_dashboard() -> 'children'), 0, 'Old consent: Zoe is not on his parent dashboard');
select is(public.record_parent_consent('2026-12-v2', false, true, false), 1, 'Sizwe consents to the new version');
select is(
  (select jsonb_agg(c ->> 'full_name') from jsonb_array_elements(public.my_parent_dashboard() -> 'children') c),
  '["Zoe Dlamini"]'::jsonb,
  'And Zoe is on his dashboard'
);
reset role;

-- If Sizwe were blocked from Zoe at another school, teaching her must not bring her
-- back onto his parent dashboard.
insert into public.school_memberships (school_id, profile_id, role, email) values
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000006', 'student', 'zoe.dlamini@other-college.test'),
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', 'parent', 'sizwe.dlamini@parents.test');
insert into public.guardianships (school_id, parent_profile_id, student_profile_id, relationship, status, blocked_reason) values
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000006', 'father', 'blocked', 'Court order 2026/300');

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000006'), 1, 'Blocked elsewhere: he still sees Zoe as her teacher');
select is(jsonb_array_length(public.my_parent_dashboard() -> 'children'), 0, 'Blocked elsewhere: Zoe is not on his parent dashboard');
reset role;

delete from public.guardianships
where school_id = '10000000-0000-4000-8000-000000000002' and student_profile_id = '40000000-0000-4000-8000-000000000006';
delete from public.school_memberships
where school_id = '10000000-0000-4000-8000-000000000002'
  and profile_id in ('40000000-0000-4000-8000-000000000006', '40000000-0000-4000-8000-000000000002');

-- ---------------------------------------------------------------------------------
-- Moving a link to a different parent voids its consent
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
update public.guardianships set parent_profile_id = '40000000-0000-4000-8000-000000000008'
where parent_profile_id = '40000000-0000-4000-8000-000000000002'
  and student_profile_id = '40000000-0000-4000-8000-000000000006';
reset role;

select is(
  (select status::text from public.guardianships
   where parent_profile_id = '40000000-0000-4000-8000-000000000008'
     and student_profile_id = '40000000-0000-4000-8000-000000000006'),
  'invited',
  'Moved link: it goes back to invited'
);
select is(
  (select count(*)::int from public.parent_consents pc
   join public.guardianships g on g.id = pc.guardianship_id
   where g.student_profile_id = '40000000-0000-4000-8000-000000000006' and pc.withdrawn_at is null),
  0,
  'Moved link: Sizwe''s consent no longer counts'
);

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000006'), 0, 'Moved link: the new parent sees nothing until he consents');
reset role;

-- A consent saved for a different child than the link now points to (what a race
-- with an admin's change could leave behind) doesn't count.
insert into public.parent_consents (school_id, guardianship_id, parent_profile_id, student_profile_id, consent_version)
select g.school_id, g.id, g.parent_profile_id, '40000000-0000-4000-8000-000000000005', '2026-12-v2'
from public.guardianships g
where g.parent_profile_id = '40000000-0000-4000-8000-000000000008'
  and g.student_profile_id = '40000000-0000-4000-8000-000000000006';
update public.guardianships set status = 'active'
where parent_profile_id = '40000000-0000-4000-8000-000000000008'
  and student_profile_id = '40000000-0000-4000-8000-000000000006';

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000006'), 0, 'A consent for a different child does not let him see Zoe');
reset role;

-- Moving a link to another school voids its consent too.
insert into public.school_memberships (school_id, profile_id, role, email) values
  ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000014', 'student', 'kai.naidoo@demo-high.test'),
  ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000017', 'parent', 'lerato.khumalo@parents.test');
update public.guardianships set school_id = '10000000-0000-4000-8000-000000000001'
where parent_profile_id = '40000000-0000-4000-8000-000000000017';
select is(
  (select status::text from public.guardianships where parent_profile_id = '40000000-0000-4000-8000-000000000017'), 'invited',
  'Moved school: Lerato''s link goes back to invited'
);
select is(
  (select count(*)::int from public.parent_consents pc
   join public.guardianships g on g.id = pc.guardianship_id
   where g.parent_profile_id = '40000000-0000-4000-8000-000000000017' and pc.withdrawn_at is null),
  0,
  'Moved school: her consent is withdrawn'
);

-- An admin marking a link consent_withdrawn withdraws the consent too, so setting it
-- back to active doesn't bring access back. Liam's father (08) consents first.
select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
set local role authenticated;
select public.record_parent_consent('2026-12-v2', false, true, false);
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000005'), 1, 'Liam''s father sees Liam after consenting');
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
update public.guardianships set status = 'consent_withdrawn'
where parent_profile_id = '40000000-0000-4000-8000-000000000008'
  and student_profile_id = '40000000-0000-4000-8000-000000000005';
update public.guardianships set status = 'active'
where parent_profile_id = '40000000-0000-4000-8000-000000000008'
  and student_profile_id = '40000000-0000-4000-8000-000000000005';
reset role;

select is(
  (select count(*)::int from public.parent_consents pc
   join public.guardianships g on g.id = pc.guardianship_id
   where g.parent_profile_id = '40000000-0000-4000-8000-000000000008'
     and g.student_profile_id = '40000000-0000-4000-8000-000000000005'
     and pc.withdrawn_at is null),
  0,
  'Marked withdrawn by an admin: the consent is withdrawn'
);

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.profiles where id = '40000000-0000-4000-8000-000000000005'), 0, 'Set back to active: he needs to consent again');
reset role;

select * from finish();
rollback;

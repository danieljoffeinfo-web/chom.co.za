-- Parent links, consent and the parent dashboard (docs/design/parent-dashboard.md §2, §3).
--
-- Acceptance criteria covered:
--   * A parent cannot see any learner data before consent is recorded
--   * A blocked guardian sees nothing for that learner, even by asking directly
--   * A cross-school guardian sees only their own learners in each school
-- Plus: withdrawing consent, a new consent version, and who may change links.
--
-- Seed: Ngozi (07) is Amara's mother at Demo High and Kai's guardian at Other College.
-- Lerato (17) is Kai's mother. Every seeded parent has consented to 2026-11-draft-1.

begin;
create extension if not exists pgtap with schema extensions;

select plan(43);

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
select throws_ok(
  $$ select public.withdraw_parent_consent(
       (select id from public.guardianships where parent_profile_id = '40000000-0000-4000-8000-000000000007' limit 1)) $$,
  '22023', 'No active link to withdraw',
  'A parent cannot withdraw another parent''s consent'
);
reset role;

-- A new version of the consent text: everyone must consent again.
insert into public.parent_consent_versions (version, published_at) values ('2026-12-v2', now() - interval '1 minute');

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000017","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.enrolments), 0, 'New consent version: Lerato sees nothing until she consents again');
select is(public.record_parent_consent('2026-12-v2', false, true, false), 1, 'Lerato consents to the new version');
select is((select count(*)::int from public.enrolments), 1, 'And sees Kai again');
reset role;

select * from finish();
rollback;

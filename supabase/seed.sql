-- Local development seed aligned with the static prototypes (Class 10B).
-- Auth users are created so local apps and pgTAP can sign in as roles.
-- Passwords are only for local use: password = "password".

create extension if not exists "pgcrypto";

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'authenticated',
    'authenticated',
    'teacher@chom.local',
    crypt('password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Mr Dlamini"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'authenticated',
    'authenticated',
    'student@chom.local',
    crypt('password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Thandi Nkosi"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'authenticated',
    'authenticated',
    'parent@chom.local',
    crypt('password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Parent Nkosi"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'authenticated',
    'authenticated',
    'outsider@chom.local',
    crypt('password', gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Other School User"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
  );

insert into auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
values
  (
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    jsonb_build_object(
      'sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'email', 'teacher@chom.local'
    ),
    'email',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    now(),
    now(),
    now()
  ),
  (
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    jsonb_build_object(
      'sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'email', 'student@chom.local'
    ),
    'email',
    'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    now(),
    now(),
    now()
  ),
  (
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    jsonb_build_object(
      'sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      'email', 'parent@chom.local'
    ),
    'email',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    now(),
    now(),
    now()
  ),
  (
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    jsonb_build_object(
      'sub', 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      'email', 'outsider@chom.local'
    ),
    'email',
    'dddddddd-dddd-dddd-dddd-dddddddddddd',
    now(),
    now(),
    now()
  );

insert into public.profiles (id, full_name, preferred_name) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Mr Dlamini', 'Mr Dlamini'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Thandi Nkosi', 'Thandi'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Parent Nkosi', 'Parent'),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Other School User', 'Other');

insert into public.schools (id, name, ednana_id) values
  ('11111111-1111-1111-1111-111111111111', 'Chom Demo High', 'ednana-school-a'),
  ('22222222-2222-2222-2222-222222222222', 'Other High', 'ednana-school-b');

insert into public.school_memberships (school_id, person_id, role) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'teacher'),
  ('11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'student'),
  ('11111111-1111-1111-1111-111111111111', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'parent'),
  ('22222222-2222-2222-2222-222222222222', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'teacher');

insert into public.classes (id, school_id, name, grade) values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '11111111-1111-1111-1111-111111111111', '10B', '10');

insert into public.subjects (id, school_id, name, short_code, color) values
  ('ffffffff-ffff-ffff-ffff-ffffffffffff', '11111111-1111-1111-1111-111111111111', 'Mathematics', 'Ma', '#1967d2');

insert into public.class_subjects (id, school_id, class_id, subject_id, teacher_id, topic)
values (
  '99999999-9999-9999-9999-999999999999',
  '11111111-1111-1111-1111-111111111111',
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'Functions & graphs'
);

insert into public.enrolments (school_id, class_id, student_id)
values (
  '11111111-1111-1111-1111-111111111111',
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
);

insert into public.guardianships (school_id, parent_id, learner_id, relationship)
values (
  '11111111-1111-1111-1111-111111111111',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'parent'
);

insert into public.tasks (school_id, class_subject_id, title, body, due_on, created_by)
values (
  '11111111-1111-1111-1111-111111111111',
  '99999999-9999-9999-9999-999999999999',
  'Complete the functions worksheet',
  'Complete questions 1–8. Show your working.',
  '2026-10-09',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
);

insert into public.assignments (
  school_id, class_subject_id, title, body, due_on, marks, status, created_by
) values
  (
    '11111111-1111-1111-1111-111111111111',
    '99999999-9999-9999-9999-999999999999',
    'Quadratic functions investigation',
    'Explore how a, b and c change the shape of a parabola.',
    '2026-10-14',
    50,
    'published',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  (
    '11111111-1111-1111-1111-111111111111',
    '99999999-9999-9999-9999-999999999999',
    'Draft only assignment',
    'Students must not see this yet.',
    '2026-10-20',
    20,
    'draft',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  );

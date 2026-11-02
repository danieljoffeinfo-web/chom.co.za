-- pgTAP: school tenancy and role visibility for the core tables.
-- Relies on supabase/seed.sql (applied on db reset / start).
begin;

select plan(12);

create schema if not exists test;

create or replace function test.set_auth_user(p_user_id uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config('request.jwt.claim.role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

create or replace function test.clear_auth()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role anon';
end;
$$;

-- Anonymous callers see nothing.
select test.clear_auth();

select is(
  (select count(*)::int from public.schools),
  0,
  'anon cannot read schools'
);

select is(
  (select count(*)::int from public.assignments),
  0,
  'anon cannot read assignments'
);

-- Teacher at school A can see school A but not school B.
select test.set_auth_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

select is(
  (select count(*)::int from public.schools),
  1,
  'teacher sees only their school'
);

select ok(
  exists (
    select 1 from public.schools
    where id = '11111111-1111-1111-1111-111111111111'
  ),
  'teacher can read school A'
);

select is(
  (select count(*)::int from public.assignments where status = 'draft'),
  1,
  'teacher can see draft assignments'
);

-- Student at school A cannot see the other school or draft work.
select test.set_auth_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

select is(
  (select count(*)::int from public.schools),
  1,
  'student sees only their school'
);

select is(
  (select count(*)::int from public.assignments where status = 'draft'),
  0,
  'student cannot see draft assignments'
);

select is(
  (select count(*)::int from public.assignments where status = 'published'),
  1,
  'student can see published assignments'
);

select ok(
  exists (
    select 1 from public.class_subjects
    where id = '99999999-9999-9999-9999-999999999999'
  ),
  'student can see their class subject'
);

-- Parent linked by guardianship can see the learner enrolment.
select test.set_auth_user('cccccccc-cccc-cccc-cccc-cccccccccccc');

select ok(
  exists (
    select 1 from public.enrolments
    where student_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  ),
  'parent can read learner enrolment via guardianship'
);

select is(
  (select count(*)::int from public.assignments where status = 'draft'),
  0,
  'parent cannot see draft assignments'
);

-- Outsider at school B cannot read school A data.
select test.set_auth_user('dddddddd-dddd-dddd-dddd-dddddddddddd');

select is(
  (select count(*)::int from public.schools where id = '11111111-1111-1111-1111-111111111111'),
  0,
  'outsider cannot read school A'
);

select is(
  (select count(*)::int from public.class_subjects),
  0,
  'outsider cannot read school A class subjects'
);

select * from finish();
rollback;

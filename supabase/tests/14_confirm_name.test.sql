-- The full name typed on a first sign-in: only for your own profile, tidied, and
-- recorded so it's asked only once.

begin;
create extension if not exists pgtap with schema extensions;

select plan(8);

create function pg_temp.as_user(p_user text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
end;
$$;

select ok(
  not has_function_privilege('anon', 'public.confirm_my_name(text)', 'EXECUTE'),
  'Nobody signed out can set a name'
);

-- Amara (a student) on her first sign-in.
select pg_temp.as_user('30000000-0000-4000-8000-000000000004');
set local role authenticated;

select is(
  (select name_confirmed_at from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  null,
  'Before the first sign-in the name is not confirmed'
);
select lives_ok(
  $$ select public.confirm_my_name('  Amara   Chioma  Nwosu ') $$,
  'A student confirms her full name'
);
select is(
  (select full_name from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  'Amara Chioma Nwosu',
  'It is saved tidied (spaces trimmed and squeezed)'
);
select isnt(
  (select name_confirmed_at from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  null,
  'and marked confirmed, so it is not asked again'
);
select throws_ok(
  $$ select public.confirm_my_name(' ') $$,
  '22023', null,
  'An empty name is refused'
);
select throws_ok(
  $$ select public.confirm_my_name(repeat('a', 121)) $$,
  '22023', null,
  'So is one over 120 characters'
);
reset role;

-- Someone signed in but not on any school's list has no profile to name.
select pg_temp.as_user('30000000-0000-4000-8000-0000000000ff');
set local role authenticated;
select throws_ok(
  $$ select public.confirm_my_name('Someone Else') $$,
  '42501', null,
  'A login with no profile cannot set a name'
);
reset role;

select * from finish();
rollback;

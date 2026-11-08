-- The full name typed on a first sign-in: people choose their own name, for their own
-- profile only. It's tidied, recorded so it's asked only once, and the school's
-- original name is kept.

begin;
create extension if not exists pgtap with schema extensions;

select plan(11);

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

-- Amara Nwosu (a student) on her first sign-in.
select pg_temp.as_user('30000000-0000-4000-8000-000000000004');
set local role authenticated;

select is(
  (select name_confirmed_at from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  null,
  'Before the first sign-in the name is not confirmed'
);
select is(
  public.confirm_my_name(E'  Amara\t Chioma  Nwosu '),
  true,
  'A student chooses her own name'
);
select is(
  (select full_name from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  'Amara Chioma Nwosu',
  'It becomes her name, tidied (spaces trimmed and squeezed)'
);
select is(
  (select school_full_name from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  'Amara Nwosu',
  'The school''s original name is kept'
);
select isnt(
  (select name_confirmed_at from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  null,
  'and the name is marked confirmed, so it is not asked again'
);
select lives_ok(
  $$ select public.confirm_my_name('Amara N') $$,
  'Choosing again later works'
);
select is(
  (select school_full_name from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  'Amara Nwosu',
  'and still keeps the school''s original name, not the one chosen before'
);
select throws_ok(
  $$ select public.confirm_my_name(E'\t\tA\n') $$,
  '22023', null,
  'A one-letter name is refused, whatever whitespace is around it'
);
select throws_ok(
  $$ select public.confirm_my_name(repeat('a', 121)) $$,
  '22023', null,
  'A name over 120 characters is refused'
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

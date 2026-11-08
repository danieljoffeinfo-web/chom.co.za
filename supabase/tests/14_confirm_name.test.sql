-- The full name typed on a first sign-in is a check: it must match the name on the
-- school's list for the signed-in account. It never changes that name, and it is
-- recorded so it's asked only once.

begin;
create extension if not exists pgtap with schema extensions;

select plan(14);

create function pg_temp.as_user(p_user text)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
end;
$$;

select ok(
  not has_function_privilege('anon', 'public.confirm_my_name(text)', 'EXECUTE'),
  'Nobody signed out can confirm a name'
);

-- Amara Nwosu (a student) on her first sign-in.
select pg_temp.as_user('30000000-0000-4000-8000-000000000004');
set local role authenticated;

select is(
  (select name_confirmed_at from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  null,
  'Before the first sign-in the name is not confirmed'
);

-- Someone else's name typed into her account (an old tab, a shared computer).
select is(
  public.confirm_my_name('Daniel Joffe'),
  false,
  'A name that is not the school''s name for this account is refused'
);
select is(
  (select full_name from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  'Amara Nwosu',
  'and the school''s name is left exactly as it was'
);
select is(
  (select name_confirmed_at from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  null,
  'and nothing is confirmed'
);
select is(
  public.confirm_my_name('Amara'),
  false,
  'Only part of the name is not enough'
);

-- Her own name, typed casually.
select is(
  public.confirm_my_name('  amara   NWOSU '),
  true,
  'Her own name matches, whatever the capitals and spaces'
);
select is(
  (select full_name from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  'Amara Nwosu',
  'Confirming never changes the school''s name'
);
select isnt(
  (select name_confirmed_at from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  null,
  'and it is marked confirmed, so it is not asked again'
);
select throws_ok(
  $$ select public.confirm_my_name(E' \t- \n') $$,
  '22023', null,
  'A blank name is refused'
);
select throws_ok(
  $$ select public.confirm_my_name(repeat('a', 121)) $$,
  '22023', null,
  'A name over 120 characters is refused'
);
reset role;

-- Sizwe is on the list with a middle name; he can leave it out, or type it.
update public.profiles set full_name = 'Sizwe Themba Dlamini'
where id = '40000000-0000-4000-8000-000000000002';
select pg_temp.as_user('30000000-0000-4000-8000-000000000002');
set local role authenticated;
select is(
  public.confirm_my_name('Sizwe Dlamini'),
  true,
  'First name and surname are enough when the list has a middle name'
);
select is(
  public.confirm_my_name('Themba Dlamini'),
  false,
  'but a middle name in place of the first name is not'
);
reset role;

-- Someone signed in but not on any school's list has no name to confirm.
select pg_temp.as_user('30000000-0000-4000-8000-0000000000ff');
set local role authenticated;
select throws_ok(
  $$ select public.confirm_my_name('Someone Else') $$,
  '42501', null,
  'A login with no profile cannot confirm a name'
);
reset role;

select * from finish();
rollback;

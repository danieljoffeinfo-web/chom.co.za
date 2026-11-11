-- Signing in with an emailed code at a school whose domain is set to 'email_code'.
--
-- Setup (inside this test's transaction):
--   * Other College's domain other-college.test signs in with an email code.
--   * On its roster: Lindi (student), Pule (parent) and Grace (teacher), each with an
--     other-college.test email, plus Kofi, who is only listed with a Google login.

begin;
create extension if not exists pgtap with schema extensions;

select plan(9);

insert into public.school_group_domains (school_group_id, domain, provider) values
  ('80000000-0000-4000-8000-000000000002', 'other-college.test', 'email_code');

insert into public.profiles (id, full_name) values
  ('40000000-0000-4000-8000-000000000051', 'Lindi Dube'),
  ('40000000-0000-4000-8000-000000000052', 'Pule Dube'),
  ('40000000-0000-4000-8000-000000000053', 'Grace Mokoena'),
  ('40000000-0000-4000-8000-000000000054', 'Kofi Mensah'),
  ('40000000-0000-4000-8000-000000000055', 'Thandi Unconfirmed');

insert into public.school_memberships (school_id, profile_id, role, email, status) values
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000051', 'student', 'lindi@other-college.test', 'active'),
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000052', 'parent', 'pule@other-college.test', 'active'),
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000053', 'teacher', 'grace@other-college.test', 'active'),
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000054', 'student', 'kofi@other-college.test', 'active'),
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000055', 'student', 'thandi@other-college.test', 'active');

-- Logins, as Supabase Auth creates them. A verified code confirms the email.
insert into auth.users (id, email, email_confirmed_at) values
  ('30000000-0000-4000-8000-000000000051', 'Lindi@other-college.test', now()),  -- email code
  ('30000000-0000-4000-8000-000000000052', 'pule@other-college.test', now()),   -- email code
  ('30000000-0000-4000-8000-000000000053', 'grace@other-college.test', now()),  -- email code
  ('30000000-0000-4000-8000-000000000054', 'kofi@other-college.test', now()),   -- Google
  ('30000000-0000-4000-8000-000000000055', 'thandi@other-college.test', null),  -- code never entered
  ('30000000-0000-4000-8000-000000000056', 'nobody@other-college.test', now()); -- email code, not on roster

insert into auth.identities (user_id, provider, provider_id, identity_data) values
  ('30000000-0000-4000-8000-000000000051', 'email', 'e-51', '{"email":"Lindi@other-college.test"}'),
  ('30000000-0000-4000-8000-000000000052', 'email', 'e-52', '{"email":"pule@other-college.test"}'),
  ('30000000-0000-4000-8000-000000000053', 'email', 'e-53', '{"email":"grace@other-college.test"}'),
  ('30000000-0000-4000-8000-000000000054', 'google', 'g-54', '{"email":"kofi@other-college.test"}'),
  ('30000000-0000-4000-8000-000000000055', 'email', 'e-55', '{"email":"thandi@other-college.test"}'),
  ('30000000-0000-4000-8000-000000000056', 'email', 'e-56', '{"email":"nobody@other-college.test"}');

-- Calls link_my_account() as the given login.
create function pg_temp.link_as(p_user_id text)
returns text
language plpgsql
as $$
declare
  result text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
  result := public.link_my_account();
  reset role;
  return result;
end;
$$;

select is(pg_temp.link_as('30000000-0000-4000-8000-000000000051'), 'linked',
  'A student signing in with an email code links to the roster (email case ignored)');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000052'), 'linked',
  'A parent on the school domain links the same way');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000053'), 'linked',
  'A teacher on the school domain links the same way');
select is(
  (select count(*)::int from public.profiles
   where id in ('40000000-0000-4000-8000-000000000051', '40000000-0000-4000-8000-000000000052',
                '40000000-0000-4000-8000-000000000053')
     and user_id is not null),
  3,
  'All three roster profiles now belong to their logins'
);

select is(pg_temp.link_as('30000000-0000-4000-8000-000000000054'), 'wrong_sign_in_method',
  'A Google login is not accepted for an email-code school');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000055'), 'wrong_sign_in_method',
  'An email login whose code was never entered does not link');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000056'), 'not_on_roster',
  'A school email that is not on the roster links to nothing');

select is(
  public.resolve_curriculum_subject('IEB', 'Afrikaans SL', 10),
  (select s.id from public.curriculum_subjects s where s.name = 'Afrikaans First Additional Language'),
  '"Afrikaans SL" means Afrikaans First Additional Language'
);
select is(
  public.resolve_curriculum_subject('IEB', 'Afrikaans Second Language', 12),
  (select s.id from public.curriculum_subjects s where s.name = 'Afrikaans First Additional Language'),
  '"Afrikaans Second Language" means Afrikaans First Additional Language'
);

select * from finish();
rollback;

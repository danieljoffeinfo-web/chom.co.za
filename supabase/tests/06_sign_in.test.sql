-- Signing in: linking a login to the right roster entry, and only when the login
-- proves the email the way the school allows.
--
-- Setup (inside this test's transaction):
--   * Demo High's domain demo-high.test signs in with Microsoft, tenant T1.
--   * Sipho (09) is on Demo High's roster, never signed in.
--   * New roster people: Nomsa (21, student), Rosa (22, parent with a personal email),
--     two profiles sharing one email (23, 24), and an inactive learner (25).

begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

-- ---------------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------------

insert into public.school_group_domains (school_group_id, domain, provider, microsoft_tenant_id) values
  ('80000000-0000-4000-8000-000000000001', 'demo-high.test', 'microsoft', 'aaaaaaaa-0000-4000-8000-000000000001');

insert into public.profiles (id, full_name) values
  ('40000000-0000-4000-8000-000000000021', 'Nomsa Zulu'),
  ('40000000-0000-4000-8000-000000000022', 'Rosa Pillay'),
  ('40000000-0000-4000-8000-000000000023', 'Twin One'),
  ('40000000-0000-4000-8000-000000000024', 'Twin Two'),
  ('40000000-0000-4000-8000-000000000025', 'Left School');

insert into public.school_memberships (school_id, profile_id, role, email, status) values
  ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000021', 'student', 'nomsa.zulu@demo-high.test', 'active'),
  ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000022', 'parent', 'rosa.pillay@personal.test', 'active'),
  ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000023', 'parent', 'shared@personal.test', 'active'),
  ('10000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000024', 'parent', 'shared@personal.test', 'active'),
  ('10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000025', 'student', 'left@demo-high.test', 'inactive');

-- Logins, as Supabase Auth would create them. Each has one identity: how they signed in.
insert into auth.users (id, email, email_confirmed_at) values
  ('30000000-0000-4000-8000-000000000009', 'Sipho.Mthembu@demo-high.test', now()), -- Microsoft, right tenant
  ('30000000-0000-4000-8000-000000000021', 'nomsa.zulu@demo-high.test', now()),    -- Microsoft, other tenant
  ('30000000-0000-4000-8000-000000000031', 'nomsa.zulu@demo-high.test', now()),    -- email link
  ('30000000-0000-4000-8000-000000000022', 'rosa.pillay@personal.test', now()),    -- email link
  ('30000000-0000-4000-8000-000000000032', 'rosa.pillay@personal.test', now()),    -- Microsoft, any tenant
  ('30000000-0000-4000-8000-000000000033', 'rosa.pillay@personal.test', null),     -- email link, not yet confirmed
  ('30000000-0000-4000-8000-000000000023', 'shared@personal.test', now()),         -- email link
  ('30000000-0000-4000-8000-000000000025', 'left@demo-high.test', now()),          -- Microsoft, right tenant
  ('30000000-0000-4000-8000-000000000026', 'stranger@personal.test', now()),       -- email link
  ('30000000-0000-4000-8000-000000000027', 'amara.nwosu@demo-high.test', now());   -- Microsoft, right tenant

insert into auth.identities (user_id, provider, provider_id, identity_data) values
  ('30000000-0000-4000-8000-000000000009', 'azure', 'ms-9',
   '{"email":"Sipho.Mthembu@demo-high.test","iss":"https://login.microsoftonline.com/aaaaaaaa-0000-4000-8000-000000000001/v2.0"}'),
  ('30000000-0000-4000-8000-000000000021', 'azure', 'ms-21',
   '{"email":"nomsa.zulu@demo-high.test","custom_claims":{"tid":"bbbbbbbb-0000-4000-8000-000000000002"}}'),
  ('30000000-0000-4000-8000-000000000031', 'email', 'e-31', '{"email":"nomsa.zulu@demo-high.test"}'),
  ('30000000-0000-4000-8000-000000000022', 'email', 'e-22', '{"email":"rosa.pillay@personal.test"}'),
  ('30000000-0000-4000-8000-000000000032', 'azure', 'ms-32',
   '{"email":"rosa.pillay@personal.test","custom_claims":{"tid":"bbbbbbbb-0000-4000-8000-000000000002"}}'),
  ('30000000-0000-4000-8000-000000000033', 'email', 'e-33', '{"email":"rosa.pillay@personal.test"}'),
  ('30000000-0000-4000-8000-000000000023', 'email', 'e-23', '{"email":"shared@personal.test"}'),
  ('30000000-0000-4000-8000-000000000025', 'azure', 'ms-25',
   '{"email":"left@demo-high.test","custom_claims":{"tid":"aaaaaaaa-0000-4000-8000-000000000001"}}'),
  ('30000000-0000-4000-8000-000000000026', 'email', 'e-26', '{"email":"stranger@personal.test"}'),
  ('30000000-0000-4000-8000-000000000027', 'azure', 'ms-27',
   '{"email":"amara.nwosu@demo-high.test","custom_claims":{"tid":"aaaaaaaa-0000-4000-8000-000000000001"}}');

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

-- ---------------------------------------------------------------------------------
-- School domain: only the school's own Microsoft tenant links
-- ---------------------------------------------------------------------------------

select is(pg_temp.link_as('30000000-0000-4000-8000-000000000009'), 'linked',
  'Microsoft login from the school''s tenant links to the roster (email case ignored)');
select is(
  (select user_id::text from public.profiles where id = '40000000-0000-4000-8000-000000000009'),
  '30000000-0000-4000-8000-000000000009',
  'Sipho''s roster profile now belongs to his login'
);
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000009'), 'already_linked',
  'Signing in again changes nothing');
select is(
  (select count(*)::int from private.audit_log
   where table_name = 'profiles' and record_id = '40000000-0000-4000-8000-000000000009'),
  1,
  'Linking is recorded in the audit log, once'
);

select is(pg_temp.link_as('30000000-0000-4000-8000-000000000021'), 'wrong_sign_in_method',
  'Microsoft login from another tenant claiming a school email does not link');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000031'), 'wrong_sign_in_method',
  'An email link to a school address does not link: that school uses Microsoft');
select is(
  (select user_id from public.profiles where id = '40000000-0000-4000-8000-000000000021'),
  null,
  'Nomsa''s profile stays unlinked after both refused attempts'
);

-- ---------------------------------------------------------------------------------
-- Other emails (parents, testing): only a confirmed email link or Google
-- ---------------------------------------------------------------------------------

select is(pg_temp.link_as('30000000-0000-4000-8000-000000000032'), 'wrong_sign_in_method',
  'A Microsoft login is never trusted for a non-school email');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000033'), 'wrong_sign_in_method',
  'An email link that was never clicked does not link');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000022'), 'linked',
  'A parent signing in with a one-time email link links to the roster');

-- ---------------------------------------------------------------------------------
-- Not on the roster, ambiguous, inactive, already taken
-- ---------------------------------------------------------------------------------

select is(pg_temp.link_as('30000000-0000-4000-8000-000000000026'), 'not_on_roster',
  'An email that is on no roster links to nothing');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000023'), 'ambiguous',
  'An email on two different profiles links to neither');
select is(
  (select count(*)::int from public.profiles
   where id in ('40000000-0000-4000-8000-000000000023', '40000000-0000-4000-8000-000000000024')
     and user_id is not null),
  0,
  'Neither profile sharing the email was linked'
);
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000025'), 'not_on_roster',
  'An inactive roster entry does not link');
select is(pg_temp.link_as('30000000-0000-4000-8000-000000000027'), 'profile_taken',
  'A second login cannot take over a profile that already has one');
select is(
  (select user_id::text from public.profiles where id = '40000000-0000-4000-8000-000000000004'),
  '30000000-0000-4000-8000-000000000004',
  'Amara''s profile still belongs to her own login'
);

-- ---------------------------------------------------------------------------------
-- Who can call it, and who can see domains and groups
-- ---------------------------------------------------------------------------------

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok(
  $$ select public.link_my_account() $$,
  '42501', null,
  'Signed-out visitors cannot call link_my_account'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
set local role authenticated;
select is(
  (select count(*)::int from public.school_group_domains),
  0,
  'A student cannot see school domains'
);
select results_eq(
  $$ select slug from public.school_groups $$,
  $$ values ('demo-high') $$,
  'A student sees only her own school''s group'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$ select domain from public.school_group_domains $$,
  $$ values ('demo-high.test') $$,
  'A school admin sees their own group''s domains'
);
reset role;

select set_config('request.jwt.claims', '{"sub":"30000000-0000-4000-8000-000000000011","role":"authenticated"}', true);
set local role authenticated;
select is(
  (select count(*)::int from public.school_group_domains),
  0,
  'Another school''s admin cannot see them'
);
reset role;

select throws_ok(
  $$ insert into public.school_group_domains (school_group_id, domain, provider, microsoft_tenant_id) values
     ('80000000-0000-4000-8000-000000000002', 'demo-high.test', 'microsoft', 'cccccccc-0000-4000-8000-000000000003') $$,
  '23505', null,
  'A domain can belong to only one school group'
);

select * from finish();
rollback;

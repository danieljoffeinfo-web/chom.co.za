-- Removing deleted tasks' files: only the scheduled job (with the Vault token) can
-- claim and clear the queue; nobody signed in can. Parts that need Vault or pg_cron
-- are skipped where they aren't installed (a plain Postgres used for quick checks).

begin;
create extension if not exists pgtap with schema extensions;

select plan(9);

insert into private.task_file_cleanup (path)
values ('10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-0000000000aa/'),
       ('10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-0000000000aa/old.pdf');

select ok(
  not has_function_privilege('anon', 'public.claim_task_file_cleanup(text, integer)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.claim_task_file_cleanup(text, integer)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.finish_task_file_cleanup(text, bigint[])', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.finish_task_file_cleanup(text, bigint[])', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.run_task_file_cleanup()', 'EXECUTE'),
  'Nobody signed in can claim, clear or run the clean-up'
);
select ok(
  has_function_privilege('service_role', 'public.claim_task_file_cleanup(text, integer)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.finish_task_file_cleanup(text, bigint[])', 'EXECUTE'),
  'The Edge Function (service key) can'
);
select throws_ok(
  $$ select * from public.claim_task_file_cleanup('a guess') $$,
  '42501', null,
  'A wrong token is refused'
);
select lives_ok(
  $$ select private.run_task_file_cleanup() $$,
  'The job does nothing, without error, until the project is set up for it'
);

-- With Vault: the right token claims the queue, a second claim within 10 minutes
-- gets nothing, and finishing clears it.
create temp table setup as
select to_regclass('vault.decrypted_secrets') is not null as vault,
       to_regclass('cron.job') is not null as cron;
do $$
begin
  if (select vault from setup) then
    execute $q$ select vault.create_secret('test-token', 'task_cleanup_token') $q$;
  end if;
end;
$$;

select case when (select vault from setup) then
  results_eq(
    $$ select path from public.claim_task_file_cleanup('test-token') order by id $$,
    $$ values ('10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-0000000000aa/'::text),
              ('10000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-0000000000aa/old.pdf') $$,
    'The right token claims the queued folder and file'
  )
  else skip('Vault is not installed here', 1) end;

select case when (select vault from setup) then
  is(
    (select count(*)::int from public.claim_task_file_cleanup('test-token')),
    0,
    'Claimed paths are not handed out again straight away'
  )
  else skip('Vault is not installed here', 1) end;

select case when (select vault from setup) then
  is(
    public.finish_task_file_cleanup('test-token', array(select id from private.task_file_cleanup)),
    2,
    'Finishing clears the removed paths'
  )
  else skip('Vault is not installed here', 1) end;

select case when (select vault from setup) then
  ok(not exists (select 1 from private.task_file_cleanup), 'and the queue is empty')
  else skip('Vault is not installed here', 1) end;

-- cron.job only exists with pg_cron, so it's read through dynamic SQL.
create function pg_temp.cleanup_scheduled()
returns boolean language plpgsql as $$
declare
  v boolean;
begin
  execute $q$ select exists (select 1 from cron.job
                             where jobname = 'task-file-cleanup' and schedule = '*/15 * * * *') $q$
    into v;
  return v;
end;
$$;

select case when (select cron from setup) then
  ok(pg_temp.cleanup_scheduled(), 'The clean-up runs every 15 minutes')
  else skip('pg_cron is not installed here', 1) end;

select * from finish();
rollback;

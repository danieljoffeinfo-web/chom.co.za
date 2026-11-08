-- Removing the files of deleted tasks.
--
-- When a task or one of its attachments is deleted, a trigger queues the file paths in
-- private.task_file_cleanup (see the tasks migration). Files can only be removed
-- properly through the Storage API, so every 15 minutes, if the queue isn't empty, a
-- pg_cron job calls the task-file-cleanup Edge Function (supabase/functions). It
-- claims a batch of paths, removes them from the bucket with the project's service
-- key (which never leaves Supabase), and marks them done.
--
-- Only that job can trigger it: the function must present a random token kept in
-- Vault ("task_cleanup_token"), which the job reads and sends. The project URL is in
-- Vault too ("project_url"). Both are set once per project, outside migrations:
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--   select vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'task_cleanup_token');
-- Until they exist the job does nothing.

-- Tries a path again only after a while if removing it failed.
alter table private.task_file_cleanup add column attempts int not null default 0;
alter table private.task_file_cleanup add column claimed_at timestamptz;

-- The token the job sends, from Vault; null where Vault or the secret isn't there.
create function private.task_cleanup_token()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_token text;
begin
  if to_regclass('vault.decrypted_secrets') is null then
    return null;
  end if;
  execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
    into v_token using 'task_cleanup_token';
  return v_token;
end;
$$;

revoke execute on function private.task_cleanup_token() from public, anon, authenticated;

-- The function claims up to p_limit paths not tried in the last 10 minutes, the
-- least-tried first, so a path that keeps failing never crowds out new ones.
create function public.claim_task_file_cleanup(p_token text, p_limit int default 200)
returns table (id bigint, bucket_id text, path text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text := private.task_cleanup_token();
begin
  if v_token is null or p_token is distinct from v_token then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
  update private.task_file_cleanup q
     set claimed_at = now(), attempts = q.attempts + 1
   where q.id in (
     select c.id from private.task_file_cleanup c
     where c.claimed_at is null or c.claimed_at < now() - interval '10 minutes'
     order by c.attempts, c.id
     limit greatest(1, least(p_limit, 1000))
     for update skip locked
   )
  returning q.id, q.bucket_id, q.path;
end;
$$;

-- ...and clears the ones it removed.
create function public.finish_task_file_cleanup(p_token text, p_ids bigint[])
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text := private.task_cleanup_token();
  v_count int;
begin
  if v_token is null or p_token is distinct from v_token then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from private.task_file_cleanup where id = any (p_ids);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.claim_task_file_cleanup(text, int) from public, anon, authenticated;
revoke execute on function public.finish_task_file_cleanup(text, bigint[]) from public, anon, authenticated;
grant execute on function public.claim_task_file_cleanup(text, int) to service_role;
grant execute on function public.finish_task_file_cleanup(text, bigint[]) to service_role;

-- What the job runs: call the Edge Function, if there's anything to clean and the
-- project is set up for it.
create function private.run_task_file_cleanup()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_token text := private.task_cleanup_token();
begin
  if v_token is null
     or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null
     or not exists (select 1 from private.task_file_cleanup) then
    return;
  end if;
  execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
    into v_url using 'project_url';
  if v_url is null then
    return;
  end if;
  execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := 60000)'
    using rtrim(v_url, '/') || '/functions/v1/task-file-cleanup',
          '{}'::jsonb,
          jsonb_build_object('Content-Type', 'application/json', 'x-cleanup-token', v_token);
end;
$$;

revoke execute on function private.run_task_file_cleanup() from public, anon, authenticated;

-- The schedule, where pg_cron and pg_net are available (on Supabase; not on a plain
-- Postgres used for quick local checks).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron')
     and exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
    create extension if not exists pg_cron with schema pg_catalog;
    perform cron.schedule(
      'task-file-cleanup',
      '*/15 * * * *',
      'select private.run_task_file_cleanup()'
    );
  end if;
end;
$$;

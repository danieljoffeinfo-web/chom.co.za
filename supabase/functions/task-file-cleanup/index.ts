// Removes the files of deleted tasks from the "task-files" bucket.
//
// Called every 15 minutes by the pg_cron job in the task_file_cleanup migration, with
// the token from Vault in the x-cleanup-token header. It claims a batch of queued paths
// (a path ending in "/" is a whole task folder), removes them through the Storage API
// with the project's service key, and marks the removed ones done. Anything that fails
// stays queued and is tried again on a later run.
//
// Deploy with JWT checks off (the token is the check):
//   supabase functions deploy task-file-cleanup --no-verify-jwt

import { createClient } from 'npm:@supabase/supabase-js@2.118.0';

type Job = { id: number; bucket_id: string; path: string };

const BATCH = 200;

Deno.serve(async (req) => {
  const token = req.headers.get('x-cleanup-token');
  if (req.method !== 'POST' || !token) return json({ error: 'not_allowed' }, 403);

  const serviceKey =
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY') ?? '';
  const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await supabase.rpc('claim_task_file_cleanup', {
    p_token: token,
    p_limit: BATCH,
  });
  if (error) {
    const forbidden = error.code === '42501';
    return json({ error: forbidden ? 'not_allowed' : 'claim_failed' }, forbidden ? 403 : 500);
  }

  const jobs = (data ?? []) as Job[];
  const done: number[] = [];
  let removed = 0;

  for (const job of jobs) {
    const bucket = supabase.storage.from(job.bucket_id);
    try {
      if (job.path.endsWith('/')) {
        // A whole task folder: list what's left in it and remove it, page by page.
        const folder = job.path.slice(0, -1);
        for (;;) {
          const { data: files, error: listError } = await bucket.list(folder, { limit: 1000 });
          if (listError) throw listError;
          if (!files?.length) break;
          const { error: removeError } = await bucket.remove(
            files.map((f) => `${folder}/${f.name}`),
          );
          if (removeError) throw removeError;
          removed += files.length;
          if (files.length < 1000) break;
        }
      } else {
        // One file. Removing one that's already gone is not an error.
        const { error: removeError } = await bucket.remove([job.path]);
        if (removeError) throw removeError;
        removed += 1;
      }
      done.push(job.id);
    } catch (e) {
      console.error(`task-file-cleanup: ${job.path}:`, e instanceof Error ? e.message : e);
    }
  }

  if (done.length) {
    const { error: finishError } = await supabase.rpc('finish_task_file_cleanup', {
      p_token: token,
      p_ids: done,
    });
    if (finishError) return json({ error: 'finish_failed' }, 500);
  }
  return json({ claimed: jobs.length, cleared: done.length, removed });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

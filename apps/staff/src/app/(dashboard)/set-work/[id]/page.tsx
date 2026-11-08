import Link from 'next/link';
import { notFound } from 'next/navigation';

import { Icon } from '@/components/icon';
import { currentStaff } from '@/lib/current-staff';
import { createClient } from '@/lib/supabase/server';
import { formatBytes } from '@/lib/task-files';
import { dueLabel, loadSetTask } from '@/lib/tasks';

import styles from '../set-work.module.css';
import { DeleteTask } from './delete-task';

export const metadata = { title: 'Task · Chom Staff' };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** One task: what the learners see, its files, and who in each class has finished. */
export default async function TaskDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  const staff = await currentStaff();
  if (!staff) return null;
  const detail = await loadSetTask(await createClient(), staff, id);
  if (!detail) notFound();
  const { task, files, classes } = detail;

  return (
    <>
      <header className="view-header">
        <div>
          <Link className={`text-button ${styles.back}`} href="/set-work">
            <Icon name="chevron" small /> Set Work
          </Link>
          <h1>{task.title}</h1>
          <p>
            {[task.subject, task.dueAt ? dueLabel(task.dueAt) : null].filter(Boolean).join(' · ')}
          </p>
        </div>
        <div className={styles.actions}>
          <Link className="button" href={`/set-work/${task.id}/edit`}>
            Edit task
          </Link>
          <DeleteTask taskId={task.id} />
        </div>
      </header>

      <div className={styles.detail}>
        <div className={styles.card}>
          <h2>Notes</h2>
          {task.notes ? (
            <p className={styles.notes}>{task.notes}</p>
          ) : (
            <p className="muted">No notes.</p>
          )}
          <h2 style={{ marginTop: 24 }}>Files</h2>
          {files.length ? (
            <ul className={styles.files}>
              {files.map((f) => (
                <li className={styles.file} key={f.id}>
                  <span className={styles.fileName}>
                    {f.url ? (
                      <a className="text-button" href={f.url}>
                        {f.name}
                      </a>
                    ) : (
                      f.name
                    )}
                  </span>
                  <span className="muted">{formatBytes(f.size)}</span>
                </li>
              ))}
            </ul>
          ) : (
            <p className="muted">No files.</p>
          )}
        </div>

        <div className={styles.card}>
          <h2>
            Done: {task.done} of {task.learners}
          </h2>
          {!task.sent ? (
            <p className="muted">
              This task was saved but never sent to a class (a file didn’t finish uploading). Delete
              it and set it again.
            </p>
          ) : classes.length === 0 ? (
            <p className="muted">
              This task went to classes you no longer teach, so their progress isn’t shown here.
            </p>
          ) : (
            classes.map((c) => (
              <div key={c.classSubjectId}>
                <p className={styles.subjectName}>
                  {c.name} · {c.learners.filter((l) => l.done).length} of {c.learners.length} done
                </p>
                <ul className={styles.learners}>
                  {c.learners.map((l) => (
                    <li key={l.id}>
                      <span>{l.name}</span>
                      {l.done ? (
                        <span className={styles.tick}>Done</span>
                      ) : (
                        <span className={styles.waiting}>Not yet</span>
                      )}
                    </li>
                  ))}
                </ul>
              </div>
            ))
          )}
        </div>
      </div>
    </>
  );
}

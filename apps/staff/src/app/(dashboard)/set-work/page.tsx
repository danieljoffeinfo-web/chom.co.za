import Link from 'next/link';

import { Icon } from '@/components/icon';
import { currentStaff } from '@/lib/current-staff';
import { createClient } from '@/lib/supabase/server';
import { dueLabel, loadSetTasks } from '@/lib/tasks';

import styles from './set-work.module.css';

export const metadata = { title: 'Set Work · Chom Staff' };

/** The work a teacher has set, with how many learners have ticked each one off. */
export default async function SetWork() {
  const staff = await currentStaff();
  if (!staff) return null;
  const tasks = await loadSetTasks(await createClient(), staff);

  return (
    <>
      <header className="view-header">
        <div>
          <h1>Set Work</h1>
          <p>
            Homework, classwork and reading for your classes: instructions, a due date and any files
            your learners need.
          </p>
        </div>
        {staff.classes.length > 0 && (
          <Link className="button" href="/set-work/new">
            <Icon name="plus" small /> New task
          </Link>
        )}
      </header>

      {tasks.length === 0 ? (
        <section className="panel">
          <div className="empty-message">
            <Icon name="file" />
            <h2>No tasks yet</h2>
            <p>
              {staff.classes.length
                ? 'Set your first task: your learners see it on their dashboard straight away, and you see who has finished.'
                : 'Once your school allocates you a class, you can set work for it here.'}
            </p>
            {staff.classes.length > 0 && (
              <Link className="button" href="/set-work/new">
                New task
              </Link>
            )}
          </div>
        </section>
      ) : (
        <div className={styles.list}>
          {tasks.map((t) => {
            const pct = t.learners ? Math.round((t.done / t.learners) * 100) : 0;
            return (
              <Link className={styles.row} href={`/set-work/${t.id}`} key={t.id}>
                <span>
                  <span className={styles.rowTitle}>
                    {t.title}
                    {!t.sent && <span className={styles.draft}>Not sent</span>}
                  </span>
                  <span className={styles.meta}>
                    {[
                      t.subject,
                      t.classes.map((c) => c.name).join(', ') || null,
                      t.dueAt ? dueLabel(t.dueAt) : null,
                      t.files.length
                        ? `${t.files.length} file${t.files.length === 1 ? '' : 's'}`
                        : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                </span>
                {t.classes.length > 0 && (
                  <span className={styles.progress}>
                    {t.done} of {t.learners} done
                    <span className={styles.track}>
                      <i style={{ width: `${pct}%` }} />
                    </span>
                  </span>
                )}
              </Link>
            );
          })}
        </div>
      )}
    </>
  );
}

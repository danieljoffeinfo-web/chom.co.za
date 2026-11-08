import Link from 'next/link';
import { notFound } from 'next/navigation';

import { Icon } from '@/components/icon';
import { currentStaff } from '@/lib/current-staff';
import { createClient } from '@/lib/supabase/server';
import { loadSetTask } from '@/lib/tasks';

import { TaskForm } from '../../new/task-form';
import styles from '../../set-work.module.css';

export const metadata = { title: 'Edit task · Chom Staff' };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ZONE = 'Africa/Johannesburg';

/** Edit a task: its title, notes, due date, files and classes. */
export default async function EditTask({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  const staff = await currentStaff();
  if (!staff) return null;
  const detail = await loadSetTask(await createClient(), staff, id);
  if (!detail) notFound();
  const { task } = detail;

  const due = task.dueAt ? new Date(task.dueAt) : null;
  const dueOn = due ? due.toLocaleDateString('en-CA', { timeZone: ZONE }) : '';
  const dueTime = due
    ? new Intl.DateTimeFormat('en-GB', {
        hour: '2-digit',
        minute: '2-digit',
        hourCycle: 'h23',
        timeZone: ZONE,
      }).format(due)
    : '08:00';

  return (
    <>
      <header className="view-header">
        <div>
          <Link className={`text-button ${styles.back}`} href={`/set-work/${task.id}`}>
            <Icon name="chevron" small /> Back to the task
          </Link>
          <h1>Edit task</h1>
          <p>Your learners see the changes straight away.</p>
        </div>
      </header>
      <TaskForm
        classes={staff.classes.map((c) => ({
          classSubjectId: c.classSubjectId,
          className: c.className,
          grade: c.grade,
          subjectName: c.subjectName,
          learners: c.learners,
        }))}
        task={{
          id: task.id,
          schoolId: staff.schoolId,
          title: task.title,
          notes: task.notes ?? '',
          dueOn,
          dueTime,
          subjectName: task.subject,
          classSubjectIds: task.classes.map((c) => c.classSubjectId),
          files: task.files.map((f) => ({ id: f.id, name: f.name, size: f.size })),
        }}
      />
    </>
  );
}

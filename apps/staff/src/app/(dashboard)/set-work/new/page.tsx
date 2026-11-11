import Link from 'next/link';
import { redirect } from 'next/navigation';

import { Icon } from '@chom/dashboard';
import { currentStaff } from '@/lib/current-staff';

import styles from '../set-work.module.css';
import { TaskForm } from './task-form';

export const metadata = { title: 'New task · Chom Staff' };

/** A teacher sets a task: instructions, a due date, classes and files. */
export default async function NewTask() {
  const staff = await currentStaff();
  if (!staff) return null;
  if (!staff.classes.length) redirect('/set-work');

  return (
    <>
      <header className="view-header">
        <div>
          <Link className={`text-button ${styles.back}`} href="/set-work">
            <Icon name="chevron" small /> Set Work
          </Link>
          <h1>New task</h1>
          <p>Your learners see it on their dashboard as soon as you set it.</p>
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
      />
    </>
  );
}

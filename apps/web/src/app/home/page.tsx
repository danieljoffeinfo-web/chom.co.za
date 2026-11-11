import Link from 'next/link';
import { redirect } from 'next/navigation';

import { SESSION_LENGTHS, STUDY_METHODS, STUDY_TIMES, loadStudentContext } from '@/lib/student';
import { createClient } from '@/lib/supabase/server';

import styles from './home.module.css';
import { Logo } from '@/components/logo';

export const metadata = { title: 'Home · Chom Learn' };

/** Placeholder home until the student dashboard is connected: shows the saved answers. */
export default async function Home() {
  const supabase = await createClient();
  const student = await loadStudentContext(supabase);
  if (!student) redirect('/start');
  if (!student.studyProfile?.onboarding_completed_at) redirect('/onboarding');

  const goals = new Map(student.goals.map((g) => [g.subject_id, g]));
  const label = <T extends string>(options: { value: T; label: string }[], values: T[]) =>
    options
      .filter((o) => values.includes(o.value))
      .map((o) => o.label)
      .join(', ') || '—';

  return (
    <main className={styles.page}>
      <header className={styles.header}>
        <p className={styles.brand}>
          <Logo />
        </p>
        <form action="/sign-out" method="post">
          <button className={styles.signOut} type="submit">
            Sign out
          </button>
        </form>
      </header>

      <h1 className={styles.title}>You’re all set, {student.name}.</h1>
      <p className={styles.muted}>
        {student.grade !== null && `Grade ${student.grade} · `}
        {student.schoolName}. Here’s what Chom knows about how you study.
      </p>

      <section className={styles.card}>
        <h2 className={styles.cardTitle}>Your goals</h2>
        <ul className={styles.goals}>
          {student.subjects.map((s) => {
            const goal = goals.get(s.id);
            return (
              <li key={s.id}>
                <span>
                  {s.name}
                  {goal?.is_focus && <em className={styles.focusTag}>Focus</em>}
                </span>
                <strong>{goal?.target_percent != null ? `${goal.target_percent}%` : '—'}</strong>
              </li>
            );
          })}
        </ul>
      </section>

      <section className={styles.card}>
        <h2 className={styles.cardTitle}>How you study</h2>
        <dl className={styles.facts}>
          <dt>In one go</dt>
          <dd>
            {SESSION_LENGTHS.find((o) => o.value === student.studyProfile?.session_length)?.label ??
              '—'}
          </dd>
          <dt>How</dt>
          <dd>{label(STUDY_METHODS, student.studyProfile.study_methods)}</dd>
          <dt>When</dt>
          <dd>{label(STUDY_TIMES, student.studyProfile.study_times)}</dd>
        </dl>
      </section>

      <a className={styles.dashboard} href="/app">
        Open my dashboard
      </a>
      <Link className={styles.edit} href="/onboarding">
        Edit my answers
      </Link>
    </main>
  );
}

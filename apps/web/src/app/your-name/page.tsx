import { redirect } from 'next/navigation';

import { parseLoginAs } from '@/lib/login-intent';
import { loadMyName } from '@/lib/my-name';
import { createClient } from '@/lib/supabase/server';

import styles from '../sign-in/sign-in.module.css';
import { NameForm } from './name-form';

export const metadata = { title: 'Your name · Chom Learn' };

/** The last step of a first sign-in: the person types their full name. */
export default async function YourName({
  searchParams,
}: {
  searchParams: Promise<{ as?: string }>;
}) {
  const loginAs = parseLoginAs((await searchParams).as);
  const next = `/start${loginAs === 'staff' ? '?as=staff' : ''}`;
  const me = await loadMyName(await createClient());
  if (!me || me.confirmed) redirect(next);

  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <p className={styles.brand}>chom learn</p>
        <h1 className={styles.title}>What’s your full name?</h1>
        <p className={styles.muted}>This is the name your teachers and school will see.</p>
        <NameForm schoolName={me.fullName} next={next} />
      </div>
    </main>
  );
}

import { redirect } from 'next/navigation';

import { parseLoginAs } from '@/lib/login-intent';
import { loadMyName } from '@/lib/my-name';
import { createClient } from '@/lib/supabase/server';

import styles from '../sign-in/sign-in.module.css';
import { NameForm } from './name-form';
import { Logo } from '@/components/logo';

export const metadata = { title: 'Your name · Chom Learn' };

/**
 * The last step of a first sign-in: the person types their full name, and that becomes
 * their name. It says which account is signed in, so someone who finds another
 * person's account open (an old tab, a shared computer) can tell, and sign out.
 */
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
        <p className={styles.brand}>
          <Logo />
        </p>
        <h1 className={styles.title}>What’s your full name?</h1>
        <p className={styles.muted}>This is the name your teachers and school will see.</p>
        {me.email && (
          <p className={styles.account}>
            Signed in as <strong>{me.email}</strong>
          </p>
        )}
        <NameForm next={next} />
        <form className={styles.switch} action="/sign-out" method="post">
          <button className={styles.linkButton} type="submit">
            Not you? Sign out
          </button>
        </form>
      </div>
    </main>
  );
}

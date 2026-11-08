import Link from 'next/link';

import { parseLoginAs } from '@/lib/login-intent';

import { SignInForm } from './sign-in-form';
import styles from './sign-in.module.css';

export const metadata = { title: 'Sign in · Chom Learn' };

export default async function SignIn({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; as?: string }>;
}) {
  const { error, as } = await searchParams;
  const loginAs = parseLoginAs(as);
  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <p className={styles.brand}>chom learn</p>
        <h1 className={styles.title}>{loginAs === 'staff' ? 'Teacher sign in' : 'Sign in'}</h1>
        <p className={styles.muted}>
          {loginAs === 'staff'
            ? 'For teachers and school staff. Use your school email.'
            : 'Use the email your school knows you by.'}
        </p>
        {error === 'link' && (
          <p className={styles.error} role="alert">
            That sign-in didn’t work. Please sign in again.
          </p>
        )}
        <SignInForm loginAs={loginAs} />
        <p className={styles.switch}>
          {loginAs === 'staff' ? (
            <Link href="/sign-in">Student or parent? Sign in here</Link>
          ) : (
            <Link href="/sign-in?as=staff">Teacher? Sign in here</Link>
          )}
        </p>
      </div>
    </main>
  );
}

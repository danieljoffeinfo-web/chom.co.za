import Link from 'next/link';

import { parseLoginAs } from '@/lib/login-intent';

import { SignInForm } from './sign-in-form';
import styles from './sign-in.module.css';

export const metadata = { title: 'Sign in · Chom Learn' };

const DOORS = {
  learner: {
    title: 'Sign in',
    intro: 'Use the email your school knows you by.',
    switchLabel: 'Student? Sign in here',
    href: '/sign-in',
  },
  staff: {
    title: 'Teacher sign in',
    intro: 'For teachers and school staff. Use your school email.',
    switchLabel: 'Teacher? Sign in here',
    href: '/sign-in?as=staff',
  },
  parent: {
    title: 'Parent sign in',
    intro: 'Use the email you gave your child’s school.',
    switchLabel: 'Parent? Sign in here',
    href: '/sign-in?as=parent',
  },
} as const;

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
        <h1 className={styles.title}>{DOORS[loginAs].title}</h1>
        <p className={styles.muted}>{DOORS[loginAs].intro}</p>
        {error === 'link' && (
          <p className={styles.error} role="alert">
            That sign-in link has expired or was already used. Please ask for a new one.
          </p>
        )}
        <SignInForm loginAs={loginAs} />
        <p className={styles.switch}>
          {(['learner', 'staff', 'parent'] as const)
            .filter((door) => door !== loginAs)
            .map((door) => (
              <Link key={door} href={DOORS[door].href}>
                {DOORS[door].switchLabel}
              </Link>
            ))}
        </p>
      </div>
    </main>
  );
}

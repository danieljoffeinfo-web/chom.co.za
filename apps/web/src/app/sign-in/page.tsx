import Link from 'next/link';

import { parseLoginAs } from '@/lib/login-intent';

import { SignInForm } from './sign-in-form';
import styles from './sign-in.module.css';
import { Logo } from '@/components/logo';

export const metadata = { title: 'Sign in · Chom Learn' };

/** Who's signing in. Students and parents use the normal sign-in; teachers the staff one. */
const DOORS = {
  student: {
    label: 'Student',
    title: 'Student sign in',
    hint: 'Use the email your school knows you by.',
  },
  parent: {
    label: 'Parent',
    title: 'Parent sign in',
    hint: 'Use the email your school knows you by.',
  },
  staff: {
    label: 'Teacher',
    title: 'Teacher sign in',
    hint: 'For teachers and school staff. Use your school email.',
  },
} as const;

type Door = keyof typeof DOORS;

function parseDoor(value: string | undefined): Door | null {
  return value && value in DOORS ? (value as Door) : null;
}

export default async function SignIn({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; as?: string }>;
}) {
  const { error, as } = await searchParams;
  const door = parseDoor(as);
  const loginAs = parseLoginAs(as);
  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <Link className={styles.brand} href="/" aria-label="Chom home">
          <Logo />
        </Link>
        <h1 className={styles.title}>{door ? DOORS[door].title : 'Sign in'}</h1>
        <p className={styles.muted}>{door ? DOORS[door].hint : 'Who’s signing in?'}</p>
        {error === 'link' && (
          <p className={styles.error} role="alert">
            That sign-in didn’t work. Please sign in again.
          </p>
        )}
        {door ? (
          <>
            <SignInForm loginAs={loginAs} />
            <p className={styles.switch}>
              <Link href="/sign-in">
                <span aria-hidden="true">←</span> Not a {DOORS[door].label.toLowerCase()}? Go back
              </Link>
            </p>
          </>
        ) : (
          <ul className={styles.doors}>
            {(Object.keys(DOORS) as Door[]).map((key) => (
              <li key={key}>
                <Link className={styles.door} href={`/sign-in?as=${key}`}>
                  {DOORS[key].label}
                  <span aria-hidden="true">→</span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </div>
    </main>
  );
}

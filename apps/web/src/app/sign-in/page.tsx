import Link from 'next/link';

import { parseLoginAs } from '@/lib/login-intent';

import { SignInForm } from './sign-in-form';
import styles from './sign-in.module.css';
import { Logo } from '@/components/logo';

export const metadata = { title: 'Sign in · Chom Learn' };

/**
 * Who's signing in. Students and parents use the normal sign-in; teachers the staff one.
 * Icon shapes are from Lucide (ISC licence).
 */
const DOORS = {
  student: {
    label: 'Student',
    // Graduation cap.
    icon: (
      <>
        <path d="M21.42 10.92a1 1 0 0 0-.02-1.84l-8.57-3.9a2 2 0 0 0-1.66 0L2.6 9.08a1 1 0 0 0 0 1.83l8.57 3.91a2 2 0 0 0 1.66 0z" />
        <path d="M22 10v6" />
        <path d="M6 12.5V16a6 3 0 0 0 12 0v-3.5" />
      </>
    ),
    title: 'Student sign in',
    hint: 'Use the email your school knows you by.',
  },
  parent: {
    label: 'Parent',
    // Two people.
    icon: (
      <>
        <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
        <circle cx="9" cy="7" r="4" />
        <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
        <path d="M16 3.13a4 4 0 0 1 0 7.75" />
      </>
    ),
    title: 'Parent sign in',
    hint: 'Use the email your school knows you by.',
  },
  staff: {
    label: 'Teacher',
    // A whiteboard.
    icon: (
      <>
        <path d="M2 3h20" />
        <path d="M21 3v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V3" />
        <path d="m7 21 5-5 5 5" />
      </>
    ),
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
                  <span className={styles.doorLabel}>
                    <svg
                      className={styles.doorIcon}
                      viewBox="0 0 24 24"
                      aria-hidden="true"
                      focusable="false"
                    >
                      {DOORS[key].icon}
                    </svg>
                    {DOORS[key].label}
                  </span>
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

import type { ReactNode } from 'react';

import styles from './message.module.css';
import { Logo } from './logo';

/** A simple full-page message, e.g. "We couldn't find you at your school". */
export function Message({
  title,
  children,
  signOut = false,
}: {
  title: string;
  children: ReactNode;
  signOut?: boolean;
}) {
  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <p className={styles.brand}>
          <Logo />
        </p>
        <h1 className={styles.title}>{title}</h1>
        <p className={styles.body}>{children}</p>
        {signOut && (
          <form action="/sign-out" method="post">
            <button className={styles.button} type="submit">
              Sign out
            </button>
          </form>
        )}
      </div>
    </main>
  );
}

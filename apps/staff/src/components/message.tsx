import type { ReactNode } from 'react';

import styles from './message.module.css';
import { Logo } from './logo';

/** A simple full-page message, e.g. "This site is for school staff". */
export function Message({
  title,
  children,
  signOut = false,
  action,
}: {
  title: string;
  children: ReactNode;
  signOut?: boolean;
  /** An extra button or link, shown before Sign out. */
  action?: ReactNode;
}) {
  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <p className={styles.brand}>
          <Logo />
        </p>
        <h1 className={styles.title}>{title}</h1>
        <div className={styles.body}>{children}</div>
        {action}
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

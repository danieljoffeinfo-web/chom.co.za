import type { ReactNode } from 'react';

import styles from './message.module.css';

/** A simple full-page message, e.g. "This site is for school staff". */
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
        <p className={styles.brand}>chom staff</p>
        <h1 className={styles.title}>{title}</h1>
        <div className={styles.body}>{children}</div>
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

import styles from './student-loading.module.css';

/**
 * Shown while home, onboarding or the sign-in handoff loads the student's one
 * database call. The page stays in the same frame, so it never looks frozen.
 */
export default function StudentLoading() {
  return (
    <main className={styles.page}>
      <p className={styles.hidden} role="status">
        Loading…
      </p>
      <div aria-hidden="true" className={styles.stack}>
        <div className={styles.title} />
        <div className={styles.line} />
        <div className={styles.card} />
        <div className={styles.card} />
      </div>
    </main>
  );
}

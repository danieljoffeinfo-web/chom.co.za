import styles from './page.module.css';

/** Placeholder until the teacher dashboard and school admin are built. */
export default function Home() {
  return (
    <main className={styles.main}>
      <p className={styles.brand}>chom learn</p>
      <h1 className={styles.title}>Everything at your fingertips.</h1>
      <p className={styles.lede}>
        <strong>Study the right way with Chom.</strong> The web app for teachers, school admins,
        students and parents is being built here.
      </p>
    </main>
  );
}

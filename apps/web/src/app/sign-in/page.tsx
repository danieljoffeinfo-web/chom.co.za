import { SignInForm } from './sign-in-form';
import styles from './sign-in.module.css';

export const metadata = { title: 'Sign in · Chom Learn' };

export default async function SignIn({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <p className={styles.brand}>chom learn</p>
        <h1 className={styles.title}>Sign in</h1>
        <p className={styles.muted}>Use the email your school knows you by.</p>
        {error === 'link' && (
          <p className={styles.error} role="alert">
            That sign-in link has expired or was already used. Please ask for a new one.
          </p>
        )}
        <SignInForm />
      </div>
    </main>
  );
}

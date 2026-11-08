import { SignInForm } from './sign-in-form';
import styles from './sign-in.module.css';
import { Logo } from '@/components/logo';

export const metadata = { title: 'Sign in · Chom Staff' };

export default async function SignIn({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <p className={styles.brand}>
          <Logo />
        </p>
        <h1 className={styles.title}>Staff sign in</h1>
        <p className={styles.muted}>For teachers and school admins. Use your school email.</p>
        {error === 'link' && (
          <p className={styles.error} role="alert">
            That sign-in didn’t work. Please sign in again.
          </p>
        )}
        <SignInForm />
      </div>
    </main>
  );
}

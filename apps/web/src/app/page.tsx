import Link from 'next/link';
import { redirect } from 'next/navigation';

import { createClient } from '@/lib/supabase/server';

import styles from './page.module.css';
import { Logo } from '@/components/logo';

export default async function Landing() {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  if (data?.claims) redirect('/start');

  return (
    <main className={styles.main}>
      <p className={styles.brand}>
        <Logo />
      </p>
      <h1 className={styles.title}>Everything at your fingertips.</h1>
      <p className={styles.lede}>
        <strong>Study the right way with Chom.</strong>
      </p>
      <div className={styles.actions}>
        <Link className={styles.cta} href="/sign-in">
          Sign in
        </Link>
        <Link className={styles.secondary} href="/sign-in?as=staff">
          Teacher login
        </Link>
      </div>
    </main>
  );
}

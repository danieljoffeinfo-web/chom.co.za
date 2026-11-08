'use client';

import { useRouter } from 'next/navigation';
import { type FormEvent, useState } from 'react';

import { createClient } from '@/lib/supabase/browser';

import styles from '../sign-in/sign-in.module.css';

export function NameForm({ schoolName, next }: { schoolName: string; next: string }) {
  const router = useRouter();
  const [name, setName] = useState(schoolName);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fullName = name.trim().replace(/\s+/g, ' ');
    if (fullName.length < 2 || fullName.length > 120) {
      setError('Please type your full name.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const { error: saveError } = await createClient().rpc('confirm_my_name', {
        p_full_name: fullName,
      });
      if (saveError) throw saveError;
      router.push(next);
    } catch (thrown) {
      console.error('Saving the name failed', thrown);
      setError('We couldn’t save your name. Please try again in a moment.');
      setBusy(false);
    }
  }

  return (
    <form className={styles.form} onSubmit={onSubmit}>
      <label className={styles.label} htmlFor="full-name">
        Full name
      </label>
      <input
        id="full-name"
        className={styles.input}
        type="text"
        autoComplete="name"
        autoCapitalize="words"
        required
        maxLength={120}
        autoFocus
        value={name}
        onChange={(event) => setName(event.target.value)}
      />
      {error && (
        <p className={styles.error} role="alert">
          {error}
        </p>
      )}
      <button className={styles.primary} type="submit" disabled={busy}>
        {busy ? 'One moment…' : 'Continue'}
      </button>
    </form>
  );
}

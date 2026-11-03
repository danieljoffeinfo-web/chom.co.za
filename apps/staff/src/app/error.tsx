'use client';

import { Message } from '@/components/message';
import styles from '@/components/message.module.css';

/**
 * Catches failures the dashboard's own error screen can't: an error boundary never
 * catches errors from the layout it sits in, and the dashboard layout is where the
 * staff member's data is loaded.
 */
export default function AppError({ retry }: { error: Error; retry: () => void }) {
  return (
    <Message
      title="We couldn’t load Chom Staff"
      signOut
      action={
        <button className={styles.primary} type="button" onClick={retry}>
          Try again
        </button>
      }
    >
      <p>Something went wrong on our side. Please try again in a moment.</p>
    </Message>
  );
}

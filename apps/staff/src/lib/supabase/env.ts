import { isServerOnlyKey } from '@chom/api';

/**
 * The Supabase project the staff app talks to: the same one as the student site. Both
 * values are public: every table is protected by row-level security. Set them in Vercel
 * (and .env.local for local dev):
 *   NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
 */
export function supabaseEnv(): { url: string; publishableKey: string } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !publishableKey) {
    throw new Error(
      'Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY. See apps/staff/.env.example.',
    );
  }
  if (isServerOnlyKey(publishableKey)) {
    throw new Error(
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is a secret key; use the publishable key.',
    );
  }
  return { url, publishableKey };
}

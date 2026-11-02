import {
  createClient,
  type SupabaseClient,
  type SupabaseClientOptions,
} from '@supabase/supabase-js';

import type { Database } from './database.types';

/** A Supabase client typed against the Chom database schema. */
export type ChomClient = SupabaseClient<Database>;

export type ChomClientConfig = {
  /** The project URL, e.g. https://<project-ref>.supabase.co */
  url: string;
  /**
   * The project's public (publishable / anon) key. Safe to ship in web and mobile
   * apps: every table is protected by row-level security. Never pass the service
   * role key here; it bypasses those rules and must only be used on a server.
   */
  publishableKey: string;
  options?: SupabaseClientOptions<'public'>;
};

/**
 * Creates the one data client the web and mobile apps share. Each app passes its own
 * URL, key and options (for example, mobile supplies its secure storage for sessions).
 */
export function createChomClient({ url, publishableKey, options }: ChomClientConfig): ChomClient {
  if (!url) throw new Error('createChomClient: missing Supabase URL');
  if (!publishableKey) throw new Error('createChomClient: missing Supabase publishable key');
  if (publishableKey.startsWith('sb_secret_')) {
    throw new Error('createChomClient: a secret key was passed; apps must use the publishable key');
  }
  return createClient<Database>(url, publishableKey, options);
}

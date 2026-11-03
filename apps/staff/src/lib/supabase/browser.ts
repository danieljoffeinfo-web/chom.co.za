'use client';

import type { Database } from '@chom/api';
import { createBrowserClient } from '@supabase/ssr';

import { supabaseEnv } from './env';

/** A Supabase client for Client Components, acting as the signed-in user. */
export function createClient() {
  const { url, publishableKey } = supabaseEnv();
  return createBrowserClient<Database>(url, publishableKey);
}

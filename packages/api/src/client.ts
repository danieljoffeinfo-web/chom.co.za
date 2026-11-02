import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from './database.types';

export type ChomClient = SupabaseClient<Database>;

export type ChomClientOptions = {
  /** Optional auth persistence / headers forwarded to supabase-js. */
  auth?: {
    persistSession?: boolean;
    autoRefreshToken?: boolean;
    detectSessionInUrl?: boolean;
    storage?: {
      getItem: (key: string) => string | null | Promise<string | null>;
      setItem: (key: string, value: string) => void | Promise<void>;
      removeItem: (key: string) => void | Promise<void>;
    };
  };
  global?: {
    headers?: Record<string, string>;
  };
};

/**
 * Typed Supabase client shared by web and mobile.
 * Pass the project URL and anon (or publishable) key from each app's env.
 */
export function createChomClient(
  supabaseUrl: string,
  supabaseKey: string,
  options: ChomClientOptions = {},
): ChomClient {
  if (!supabaseUrl.trim()) {
    throw new Error('createChomClient: supabaseUrl is required');
  }
  if (!supabaseKey.trim()) {
    throw new Error('createChomClient: supabaseKey is required');
  }

  return createClient<Database>(supabaseUrl, supabaseKey, {
    auth: {
      persistSession: options.auth?.persistSession ?? true,
      autoRefreshToken: options.auth?.autoRefreshToken ?? true,
      detectSessionInUrl: options.auth?.detectSessionInUrl ?? true,
      storage: options.auth?.storage,
    },
    global: options.global,
  });
}

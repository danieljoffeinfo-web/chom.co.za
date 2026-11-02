export type ChomPublicEnv = {
  supabaseUrl: string;
  supabaseAnonKey: string;
};

type EnvMap = Record<string, string | undefined>;

function readProcessEnv(): EnvMap {
  const proc = (globalThis as { process?: { env?: EnvMap } }).process;
  return proc?.env ?? {};
}

/**
 * Reads the public Supabase env vars used by browser and React Native builds.
 * Accepts either NEXT_PUBLIC_* (web) or EXPO_PUBLIC_* (mobile) names.
 */
export function readPublicSupabaseEnv(env: EnvMap = readProcessEnv()): ChomPublicEnv {
  const supabaseUrl =
    env.NEXT_PUBLIC_SUPABASE_URL ?? env.EXPO_PUBLIC_SUPABASE_URL ?? '';
  const supabaseAnonKey =
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? '';

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error(
      'Missing Supabase public env. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY (web) or EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY (mobile).',
    );
  }

  return { supabaseUrl, supabaseAnonKey };
}

import type { createClient } from '@/lib/supabase/server';

type Client = Awaited<ReturnType<typeof createClient>>;

/**
 * The signed-in person's name as the school has it, and whether they've confirmed it
 * (the last step of their first sign-in). Null if they have no profile, or if it
 * couldn't be read: the name step is skipped rather than blocking sign-in.
 */
export async function loadMyName(
  supabase: Client,
): Promise<{ fullName: string; confirmed: boolean } | null> {
  const { data: claims } = await supabase.auth.getClaims();
  const userId = claims?.claims.sub;
  if (!userId) return null;
  const { data } = await supabase
    .from('profiles')
    .select('full_name, name_confirmed_at')
    .eq('user_id', userId)
    .maybeSingle();
  return data ? { fullName: data.full_name, confirmed: data.name_confirmed_at !== null } : null;
}

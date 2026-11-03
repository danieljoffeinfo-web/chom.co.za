/**
 * Recognises Supabase keys that must never be shipped in a web or mobile app,
 * because they bypass row-level security:
 *   - secret keys (sb_secret_…)
 *   - legacy JWT-format keys whose role is service_role
 *
 * Publishable keys (sb_publishable_…) and legacy anon keys are fine in apps.
 */
export function isServerOnlyKey(key: string): boolean {
  if (key.startsWith('sb_secret_')) return true;
  return legacyJwtRole(key) === 'service_role';
}

/** The role inside a legacy JWT-format key, or undefined if it isn't one. */
function legacyJwtRole(key: string): string | undefined {
  const parts = key.split('.');
  const payload = parts[1];
  if (parts.length !== 3 || !payload) return undefined;

  try {
    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
    const claims: unknown = JSON.parse(atob(padded));
    if (claims && typeof claims === 'object' && 'role' in claims) {
      const { role } = claims as { role: unknown };
      return typeof role === 'string' ? role : undefined;
    }
  } catch {
    // Not a JWT: treat as an unknown key, not a server key.
  }
  return undefined;
}

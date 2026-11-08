/** What we tell people about choosing a password. Supabase Auth enforces the same. */
export const PASSWORD_RULE = 'At least 8 characters, with letters and numbers.';

/**
 * Why a new password won't be accepted, or null if it's fine. Mirrors the project's
 * Auth settings (at least 8 characters, letters and digits), so people hear about it
 * before we email them a code. Supabase also refuses passwords known from data leaks;
 * only it can check that.
 */
export function passwordProblem(password: string): string | null {
  if (password.length < 8 || !/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    return `Choose a stronger password: ${PASSWORD_RULE.toLowerCase()}`;
  }
  return null;
}

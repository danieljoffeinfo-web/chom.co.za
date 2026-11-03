import { cookies } from 'next/headers';

export type Theme = 'light' | 'dark';

/** Remembered per browser, so the page is drawn in the right theme from the server. */
export const THEME_COOKIE = 'chom-staff-theme';

/** Light is the default; dark is opt-in from Settings. */
export async function currentTheme(): Promise<Theme> {
  const value = (await cookies()).get(THEME_COOKIE)?.value;
  return value === 'dark' ? 'dark' : 'light';
}

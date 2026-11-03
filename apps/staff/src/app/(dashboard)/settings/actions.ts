'use server';

import { cookies } from 'next/headers';

import { THEME_COOKIE, type Theme } from '@/lib/theme';

/** Remembers the chosen theme in this browser for a year. */
export async function saveTheme(theme: Theme) {
  (await cookies()).set(THEME_COOKIE, theme === 'dark' ? 'dark' : 'light', {
    path: '/',
    maxAge: 60 * 60 * 24 * 365,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
  });
}

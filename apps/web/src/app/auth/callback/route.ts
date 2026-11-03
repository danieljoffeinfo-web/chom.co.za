import { type NextRequest, NextResponse } from 'next/server';

import { LOGIN_AS_COOKIE, parseLoginAs } from '@/lib/login-intent';
import { createClient } from '@/lib/supabase/server';

/**
 * Where the one-time sign-in link (and later, Microsoft) sends people back to. Swaps
 * the one-time code for a session, then continues to /start, passing on which door
 * they used (Teacher login or the normal one) and forgetting it.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const code = searchParams.get('code');

  const loginAs = parseLoginAs(request.cookies.get(LOGIN_AS_COOKIE)?.value);

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      const response = NextResponse.redirect(
        `${origin}/start${loginAs === 'staff' ? '?as=staff' : ''}`,
      );
      response.cookies.delete(LOGIN_AS_COOKIE);
      return response;
    }
  }

  // A failed link keeps the door they chose, so the retry is a Teacher sign-in again.
  return NextResponse.redirect(
    `${origin}/sign-in?error=link${loginAs === 'staff' ? '&as=staff' : ''}`,
  );
}

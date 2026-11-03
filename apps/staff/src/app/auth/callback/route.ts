import { type NextRequest, NextResponse } from 'next/server';

import { createClient } from '@/lib/supabase/server';

/**
 * Where the one-time sign-in link (and later, Microsoft) sends people back to. Swaps
 * the one-time code for a session, then continues to /start.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const code = searchParams.get('code');

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(`${origin}/start`);
  }

  return NextResponse.redirect(`${origin}/sign-in?error=link`);
}

import { type NextRequest, NextResponse } from 'next/server';

import { createClient } from '@/lib/supabase/server';

/** Signs out, then back to the sign-in page. POST from the dashboard's button. */
export async function POST(request: NextRequest) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  return NextResponse.redirect(`${request.nextUrl.origin}/sign-in`, { status: 303 });
}

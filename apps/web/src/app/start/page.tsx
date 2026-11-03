import { STAFF_ORIGIN } from '@chom/api';
import { redirect } from 'next/navigation';

import { Message } from '@/components/message';
import { parseLoginAs } from '@/lib/login-intent';
import { loadStudentContext } from '@/lib/student';
import { createClient } from '@/lib/supabase/server';

export const metadata = { title: 'Signing you in · Chom Learn' };

const NOT_LINKED: Record<string, { title: string; body: string }> = {
  not_on_roster: {
    title: "We couldn't find you at your school",
    body: 'Your email isn’t on a Chom school list yet. Please check you used your school email, or speak to your teacher.',
  },
  wrong_sign_in_method: {
    title: 'Please sign in with your school account',
    body: 'Your school asks students to sign in with their school account. Use the “Sign in with Microsoft” button with your school email.',
  },
  ambiguous: {
    title: 'Your school needs to check your details',
    body: 'Your email appears more than once on your school’s list. Please ask your school to fix it, then sign in again.',
  },
  profile_taken: {
    title: 'This account is already in use',
    body: 'Someone has already signed in to this school account with a different login. Please speak to your school.',
  },
};

/**
 * After every sign-in: link the login to the school roster, then send each person to
 * their dashboard. Teacher login → the staff dashboard. Otherwise students go to
 * onboarding (first time) or their dashboard, and staff to the staff dashboard.
 */
export default async function Start({ searchParams }: { searchParams: Promise<{ as?: string }> }) {
  const loginAs = parseLoginAs((await searchParams).as);
  const supabase = await createClient();

  const { data: result, error } = await supabase.rpc('link_my_account');
  if (error) {
    return (
      <Message title="Something went wrong" signOut>
        We couldn’t finish signing you in. Please try again in a moment.
      </Message>
    );
  }

  const problem = NOT_LINKED[result];
  if (problem) {
    return (
      <Message title={problem.title} signOut>
        {problem.body}
      </Message>
    );
  }

  // Staff go to the staff dashboard on staff.chom.co.za, which shares this sign-in.
  const { data: staff } = await supabase.rpc('my_staff_dashboard');
  const isStaff = Boolean(staff);

  if (loginAs === 'staff') {
    if (isStaff) redirect(STAFF_ORIGIN);
    return (
      <Message title="This isn’t a staff account" signOut>
        Your email isn’t on your school’s staff list. If you’re a student or parent, sign out and
        use the normal Sign in. If you teach at the school, ask your school admin to add you.
      </Message>
    );
  }

  const student = await loadStudentContext(supabase);
  if (student) {
    redirect(student.studyProfile?.onboarding_completed_at ? '/app' : '/onboarding');
  }
  if (isStaff) redirect(STAFF_ORIGIN);

  return (
    <Message title="You’re signed in" signOut>
      Chom is open to students and teachers for now. Parent accounts are coming soon.
    </Message>
  );
}

import { redirect } from 'next/navigation';

import { Message } from '@/components/message';
import { loadStaffContext } from '@/lib/staff';
import { createClient } from '@/lib/supabase/server';

export const metadata = { title: 'Signing you in · Chom Staff' };

const STUDENT_SITE = 'https://chom.co.za';

const NOT_LINKED: Record<string, { title: string; body: string }> = {
  not_on_roster: {
    title: "We couldn't find you at your school",
    body: 'Your email isn’t on a Chom school’s staff list yet. Please check you used your school email, or ask your school admin to add you.',
  },
  wrong_sign_in_method: {
    title: 'Please sign in with your school account',
    body: 'Your school asks staff to sign in with their school account. Use “Sign in with Microsoft” with your school email.',
  },
  ambiguous: {
    title: 'Your school needs to check your details',
    body: 'Your email appears more than once on your school’s list. Please ask your school admin to fix it, then sign in again.',
  },
  profile_taken: {
    title: 'This account is already in use',
    body: 'Someone has already signed in to this school account with a different login. Please speak to your school admin.',
  },
};

/**
 * After every sign-in: link the login to the school roster, then let teachers and
 * school admins into the dashboard. Everyone else is pointed to the student site.
 */
export default async function Start() {
  const supabase = await createClient();

  const { data: result, error } = await supabase.rpc('link_my_account');
  if (error) {
    return (
      <Message title="Something went wrong" signOut>
        <p>We couldn’t finish signing you in. Please try again in a moment.</p>
      </Message>
    );
  }

  const problem = NOT_LINKED[result];
  if (problem) {
    return (
      <Message title={problem.title} signOut>
        <p>{problem.body}</p>
      </Message>
    );
  }

  const staff = await loadStaffContext(supabase);
  if (!staff) {
    return (
      <Message title="This site is for school staff" signOut>
        <p>Your account isn’t a teacher or school admin account.</p>
        <p>
          Students and parents sign in at <a href={STUDENT_SITE}>chom.co.za</a>.
        </p>
      </Message>
    );
  }

  redirect('/');
}

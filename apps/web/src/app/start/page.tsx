import { redirect } from 'next/navigation';

import { Message } from '@/components/message';
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
 * After every sign-in: link the login to the school roster, then send the student to
 * onboarding (first time) or home.
 */
export default async function Start() {
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

  const student = await loadStudentContext(supabase);
  if (!student) {
    return (
      <Message title="You’re signed in" signOut>
        Chom is only open to students for now. Teacher and parent accounts are coming soon.
      </Message>
    );
  }

  redirect(student.studyProfile?.onboarding_completed_at ? '/app' : '/onboarding');
}

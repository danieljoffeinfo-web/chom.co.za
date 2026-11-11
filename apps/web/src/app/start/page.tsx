import { staffOriginFor } from '@chom/api';
import { headers } from 'next/headers';
import { redirect } from 'next/navigation';

import { Message } from '@/components/message';
import { loginAsParam, parseLoginAs } from '@/lib/login-intent';
import { loadMyName } from '@/lib/my-name';
import { type GuardianLink, loadGuardianLinks } from '@/lib/parent/parent';
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

const SOMETHING_WENT_WRONG = (
  <Message title="Something went wrong" signOut>
    We couldn’t finish signing you in. Please try again in a moment.
  </Message>
);

/**
 * After every sign-in: link the login to the school roster, ask for their full name the
 * first time, then send each person to their dashboard. Teacher login → the staff
 * dashboard; Parent login → the parent dashboard. Otherwise students go to onboarding
 * (first time) or their dashboard, then staff to the staff dashboard, then parents to
 * the parent dashboard.
 */
export default async function Start({ searchParams }: { searchParams: Promise<{ as?: string }> }) {
  const loginAs = parseLoginAs((await searchParams).as);
  const supabase = await createClient();

  const { data: result, error } = await supabase.rpc('link_my_account');
  if (error) return SOMETHING_WENT_WRONG;

  const problem = NOT_LINKED[result];
  if (problem) {
    return (
      <Message title={problem.title} signOut>
        {problem.body}
      </Message>
    );
  }

  // The last step of a first sign-in: their full name.
  const me = await loadMyName(supabase);
  if (me && !me.confirmed) redirect(`/your-name${loginAsParam(loginAs)}`);

  // Parent login: the parent dashboard asks for consent first if a child still needs
  // it. A failed lookup never tells a parent they aren't one.
  if (loginAs === 'parent') {
    let links: GuardianLink[];
    try {
      links = await loadGuardianLinks(supabase);
    } catch {
      return SOMETHING_WENT_WRONG;
    }
    if (links.length) redirect('/parent');
    return (
      <Message title="This isn’t a parent account" signOut>
        Your email isn’t linked to a learner at your child’s school. Please check you used the email
        you gave the school, or ask the school to add you.
      </Message>
    );
  }

  // Staff go to the staff dashboard on staff.chom.co.za, which shares this sign-in.
  const { data: staff, error: staffError } = await supabase.rpc('my_staff_dashboard');
  // Never tell a teacher they aren't staff because the lookup failed.
  if (staffError) return SOMETHING_WENT_WRONG;
  const isStaff = Boolean(staff);
  const staffOrigin = staffOriginFor((await headers()).get('host'));
  const staffDestination = (
    <Message title="You’re signed in as staff" signOut>
      This preview can’t open the staff dashboard. Sign in on the staff site’s own preview, or at
      chom.co.za.
    </Message>
  );

  if (loginAs === 'staff') {
    if (isStaff) {
      if (staffOrigin) redirect(staffOrigin);
      return staffDestination;
    }
    return (
      <Message title="This isn’t a staff account" signOut>
        Your email isn’t on your school’s staff list. If you’re a student or parent, sign out and
        use the normal Sign in or the Parent login. If you teach at the school, ask your school
        admin to add you.
      </Message>
    );
  }

  const student = await loadStudentContext(supabase);
  if (student) {
    redirect(student.studyProfile?.onboarding_completed_at ? '/app' : '/onboarding');
  }
  if (isStaff) {
    if (staffOrigin) redirect(staffOrigin);
    return staffDestination;
  }

  let links: GuardianLink[];
  try {
    links = await loadGuardianLinks(supabase);
  } catch {
    return SOMETHING_WENT_WRONG;
  }
  if (links.length) redirect('/parent');

  return (
    <Message title="You’re signed in" signOut>
      We couldn’t find a student, staff or parent account for this email at a Chom school. Please
      speak to your school.
    </Message>
  );
}

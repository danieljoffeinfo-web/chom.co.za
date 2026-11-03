import { currentStaff } from '@/lib/current-staff';

import { ClassCards, NoClasses } from '../class-cards';

export const metadata = { title: 'My Classes · Chom Staff' };

/** The classes the teacher is allocated this year. Admins own rosters, so read-only. */
export default async function MyClasses() {
  const staff = await currentStaff();
  if (!staff) return null;

  return (
    <>
      <header className="view-header">
        <div>
          <h1>My Classes</h1>
          <p>
            The classes your school has allocated to you
            {staff.yearLabel ? ` for ${staff.yearLabel}` : ''}. Your school admin manages class
            lists.
          </p>
        </div>
      </header>
      {staff.classes.length ? <ClassCards classes={staff.classes} /> : <NoClasses />}
    </>
  );
}

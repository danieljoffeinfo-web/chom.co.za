import { currentStaff } from '@/lib/current-staff';
import { currentTheme } from '@/lib/theme';

import { ThemeSwitch } from './theme-switch';

export const metadata = { title: 'Settings · Chom Staff' };

export default async function Settings() {
  const [staff, theme] = await Promise.all([currentStaff(), currentTheme()]);
  if (!staff) return null;

  return (
    <>
      <header className="view-header">
        <div>
          <h1>Settings</h1>
          <p>
            Signed in as {staff.fullName} at {staff.schoolName}.
          </p>
        </div>
      </header>
      <section className="content-card">
        <h2>Your workspace</h2>
        <ThemeSwitch initial={theme} />
      </section>
    </>
  );
}

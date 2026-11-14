import { currentStaff } from '@/lib/current-staff';

export const metadata = { title: 'Settings · Chom Staff' };

export default async function Settings() {
  const staff = await currentStaff();
  if (!staff) return null;

  return (
    <header className="view-header">
      <div>
        <h1>Settings</h1>
        <p>
          Signed in as {staff.fullName} at {staff.schoolName}.
        </p>
      </div>
    </header>
  );
}

import { ComingSoon } from '@chom/dashboard';

export const metadata = { title: 'Calendar · Chom Staff' };

export default function Calendar() {
  return (
    <ComingSoon
      title="Calendar"
      icon="calendar"
      intro="Your timetable and lesson plan, so Chom stays in step with what you’ve taught."
      points={[
        'Your timetable, imported from the school',
        'Plan topics onto lessons and mark them as taught',
        'Test dates, with a warning when a grade already has two tests that day',
      ]}
    />
  );
}

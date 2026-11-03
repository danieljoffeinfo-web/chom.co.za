import { ComingSoon } from '@chom/dashboard';

export const metadata = { title: 'Messages · Chom Staff' };

export default function Messages() {
  return (
    <ComingSoon
      title="Messages"
      icon="message"
      intro="Talk to your classes without being on call all the time."
      points={[
        'Class announcements, with read receipts',
        'Questions and feedback kept with each Task',
        'Quiet hours, so learners know when you’ll reply',
      ]}
    />
  );
}

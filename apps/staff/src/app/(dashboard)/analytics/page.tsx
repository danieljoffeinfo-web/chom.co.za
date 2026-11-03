import { ComingSoon } from '../coming-soon';

export const metadata = { title: 'Analytics · Chom Staff' };

export default function Analytics() {
  return (
    <ComingSoon
      title="Analytics"
      icon="chart"
      intro="Only the numbers that tell you what to do next."
      points={[
        'Effort: study time, active days and on-time work',
        'Understanding: readiness by topic, and what learners are stuck on this week',
        'Who needs help, who is coasting, and who to stretch',
      ]}
    />
  );
}

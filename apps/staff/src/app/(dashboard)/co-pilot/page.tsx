import { ComingSoon } from '@chom/dashboard';

export const metadata = { title: 'Co-pilot · Chom Staff' };

export default function CoPilot() {
  return (
    <ComingSoon
      title="Co-pilot"
      icon="spark"
      intro="An assistant that only knows your classes and your content."
      points={[
        'Ask: “Who hasn’t submitted the Chapter 4 task?”',
        'Draft a worksheet, a task or feedback for you to check',
        'Every answer links to the data behind it',
      ]}
    />
  );
}

import { ComingSoon } from '../coming-soon';

export const metadata = { title: 'Set Work · Chom Staff' };

export default function SetWork() {
  return (
    <ComingSoon
      title="Set Work"
      icon="file"
      intro="Homework, classwork and tests for your classes. Each one is a Task."
      points={[
        'Create a Task from scratch, from your own content, or with the co-pilot',
        'Set a due date and choose a class or a group',
        'See who has submitted, and mark in one queue',
      ]}
    />
  );
}

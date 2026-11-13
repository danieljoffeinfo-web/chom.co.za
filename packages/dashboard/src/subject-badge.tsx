import { Icon } from './icon';
import { subjectStyle } from './subject-icon';

/**
 * A subject's square badge: the same icon and colour for that subject on every
 * dashboard. Decorative: always show the subject's name beside it.
 */
export function SubjectBadge({ name, small = false }: { name: string; small?: boolean }) {
  const { icon, color } = subjectStyle(name);
  return (
    <span className={`subject-badge ${color}${small ? ' small' : ''}`} aria-hidden="true">
      <Icon name={icon} />
    </span>
  );
}

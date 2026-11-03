/** Names of the icons in public/icons.svg (Heroicons, copied from the learner dashboard). */
export type IconName =
  | 'home'
  | 'check'
  | 'calendar'
  | 'book'
  | 'file'
  | 'chart'
  | 'spark'
  | 'message'
  | 'school'
  | 'settings'
  | 'search'
  | 'bell'
  | 'chevron'
  | 'down'
  | 'arrow'
  | 'up'
  | 'plus'
  | 'x'
  | 'menu'
  | 'heart'
  | 'leaf'
  | 'target'
  | 'sun';

export function Icon({ name, small = false }: { name: IconName; small?: boolean }) {
  return (
    <svg className={small ? 'icon small' : 'icon'} aria-hidden="true">
      <use href={`/icons.svg#i-${name}`} />
    </svg>
  );
}

/**
 * Names of the icons in icons.svg (Heroicons, copied from the learner dashboard). Each
 * app serves the sprite at /icons.svg (see iconSpriteResponse).
 */
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
  | 'sun'
  | 'ball'
  | 'cap'
  | 'user'
  | 'alert'
  | 'language'
  | 'book-open'
  | 'calculator'
  | 'briefcase'
  | 'drama'
  | 'beaker'
  | 'bolt'
  | 'globe'
  | 'clock'
  | 'banknotes'
  | 'computer'
  | 'paint'
  | 'music'
  | 'tools';

export function Icon({ name, small = false }: { name: IconName; small?: boolean }) {
  return (
    <svg className={small ? 'icon small' : 'icon'} aria-hidden="true">
      <use href={`/icons.svg#i-${name}`} />
    </svg>
  );
}

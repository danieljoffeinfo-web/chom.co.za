import type { IconName } from './icon';

/** A subject's colour family: picks its --chom-subject-* fill (@chom/tokens subjectColors). */
export type SubjectColor =
  | 'maths'
  | 'english'
  | 'language'
  | 'life-orientation'
  | 'physical-sciences'
  | 'life-sciences'
  | 'commerce'
  | 'humanities'
  | 'technology'
  | 'arts'
  | 'other';

/**
 * Most specific first: "Life Orientation" must match before "Life Sciences" would.
 * The learner dashboard (static/site/app/index.html) keeps a copy of this table: change both.
 */
const RULES: [RegExp, IconName, SubjectColor][] = [
  [/life orientation/i, 'heart', 'life-orientation'],
  [/life sciences|biology|natural sciences|marine|agricultur/i, 'beaker', 'life-sciences'],
  [/physical sciences|physics|chemistry/i, 'bolt', 'physical-sciences'],
  [/english/i, 'book-open', 'english'],
  [
    /afrikaans|isizulu|isixhosa|sesotho|sepedi|setswana|siswati|xitsonga|tshivenda|isindebele|french|german|portuguese|spanish|mandarin|latin|language/i,
    'language',
    'language',
  ],
  [/math/i, 'calculator', 'maths'],
  [/accounting/i, 'banknotes', 'commerce'],
  [/business|econom|\bems\b|tourism|consumer|hospitality/i, 'briefcase', 'commerce'],
  [/drama|theatre/i, 'drama', 'arts'],
  [/geography|social sciences/i, 'globe', 'humanities'],
  [/history/i, 'clock', 'humanities'],
  [/computer|information technology/i, 'computer', 'technology'],
  // Before "design", so Engineering Graphics and Design is technology, not art.
  [/engineering|technical|technology/i, 'tools', 'technology'],
  [/visual arts|design|creative arts|dance/i, 'paint', 'arts'],
  [/music/i, 'music', 'arts'],
];

/** A subject's badge: "Mathematical Literacy" → calculator on the maths colour. */
export function subjectStyle(subjectName: string): { icon: IconName; color: SubjectColor } {
  const rule = RULES.find(([re]) => re.test(subjectName));
  return rule ? { icon: rule[1], color: rule[2] } : { icon: 'book', color: 'other' };
}

/** The symbol for a subject's badge: "Mathematical Literacy" → calculator. */
export function subjectIcon(subjectName: string): IconName {
  return subjectStyle(subjectName).icon;
}

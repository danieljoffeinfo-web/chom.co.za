import type { IconName } from './icon';

/** Most specific first: "Life Orientation" must match before "Life Sciences" would. */
const RULES: [RegExp, IconName][] = [
  [/life orientation/i, 'heart'],
  [/life sciences|biology/i, 'beaker'],
  [/physical sciences|physics|chemistry/i, 'bolt'],
  [/english/i, 'book-open'],
  [
    /afrikaans|isizulu|isixhosa|sesotho|sepedi|setswana|siswati|xitsonga|tshivenda|isindebele|french|german|portuguese|spanish|mandarin|latin|language/i,
    'language',
  ],
  [/math/i, 'calculator'],
  [/accounting/i, 'banknotes'],
  [/business|economics/i, 'briefcase'],
  [/drama|theatre/i, 'drama'],
  [/geography/i, 'globe'],
  [/history/i, 'clock'],
  [/computer|information technology/i, 'computer'],
  [/visual arts|design/i, 'paint'],
  [/music/i, 'music'],
  [/engineering|technical|technology/i, 'tools'],
];

/** The symbol for a subject's badge: "Mathematical Literacy" → calculator. */
export function subjectIcon(subjectName: string): IconName {
  return RULES.find(([re]) => re.test(subjectName))?.[1] ?? 'book';
}

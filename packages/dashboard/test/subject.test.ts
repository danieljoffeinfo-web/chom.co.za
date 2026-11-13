import assert from 'node:assert/strict';
import { test } from 'node:test';

import { subjectStyle } from '../src/subject-icon.ts';

test('each subject gets its own fixed icon and colour', () => {
  const cases: [string, string, string][] = [
    ['Life Orientation', 'heart', 'life-orientation'],
    ['Life Sciences', 'beaker', 'life-sciences'],
    ['Natural Sciences', 'beaker', 'life-sciences'],
    ['Physical Sciences', 'bolt', 'physical-sciences'],
    ['English Home Language', 'book-open', 'english'],
    ['Afrikaans First Additional Language', 'language', 'language'],
    ['Mathematical Literacy', 'calculator', 'maths'],
    ['Advanced Programme Mathematics', 'calculator', 'maths'],
    ['Economic and Management Sciences', 'briefcase', 'commerce'],
    ['Accounting', 'banknotes', 'commerce'],
    ['Geography', 'globe', 'humanities'],
    ['History', 'clock', 'humanities'],
    ['Computer Applications Technology', 'computer', 'technology'],
    ['Engineering Graphics and Design', 'tools', 'technology'],
    ['Dramatic Arts', 'drama', 'arts'],
    ['Visual Arts', 'paint', 'arts'],
    ['Sports and Exercise Science', 'book', 'other'],
  ];
  for (const [name, icon, color] of cases) {
    assert.deepEqual(subjectStyle(name), { icon, color }, name);
  }
});

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { gradeAndClasses } from '../src/lib/parent/parent.ts';

test('a class named for its grade is enough on its own', () => {
  assert.deepEqual(gradeAndClasses(10, ['10B']), ['10B']);
  assert.deepEqual(gradeAndClasses(10, ['10B', '10C']), ['10B, 10C']);
});

test('the grade stays when a class name does not carry it', () => {
  assert.deepEqual(gradeAndClasses(10, ['Blue']), ['Grade 10', 'Blue']);
  assert.deepEqual(gradeAndClasses(10, ['10B', 'Blue']), ['Grade 10', '10B, Blue']);
  assert.deepEqual(gradeAndClasses(0, ['R1']), ['Grade R', 'R1']);
});

test('without classes, just the grade; without a grade, just the classes', () => {
  assert.deepEqual(gradeAndClasses(10, []), ['Grade 10']);
  assert.deepEqual(gradeAndClasses(null, ['10B']), ['10B']);
  assert.deepEqual(gradeAndClasses(null, []), []);
});

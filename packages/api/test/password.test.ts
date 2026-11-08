import assert from 'node:assert/strict';
import { test } from 'node:test';

import { passwordProblem } from '../src/password.ts';

test('accepts 8+ characters with letters and numbers', () => {
  assert.equal(passwordProblem('maths2026'), null);
  assert.equal(passwordProblem('Styfe School 11A'), null);
});

test('refuses short passwords', () => {
  assert.notEqual(passwordProblem('ab12cd3'), null);
});

test('refuses passwords without a letter or without a number', () => {
  assert.notEqual(passwordProblem('12345678'), null);
  assert.notEqual(passwordProblem('password'), null);
});

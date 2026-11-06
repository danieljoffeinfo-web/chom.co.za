import assert from 'node:assert/strict';
import { test } from 'node:test';

import { loginAsParam, parseLoginAs } from '../src/lib/login-intent.ts';

test('the Teacher and Parent doors are recognised', () => {
  assert.equal(parseLoginAs('staff'), 'staff');
  assert.equal(parseLoginAs('parent'), 'parent');
});

test('anything else is the normal sign-in', () => {
  for (const value of [undefined, null, '', 'learner', 'admin', 'Parent', 'parent ']) {
    assert.equal(parseLoginAs(value), 'learner');
  }
});

test('only the Teacher and Parent doors add an as= parameter', () => {
  assert.equal(loginAsParam('learner'), '');
  assert.equal(loginAsParam('staff'), '?as=staff');
  assert.equal(loginAsParam('parent'), '?as=parent');
  assert.equal(loginAsParam('parent', '&'), '&as=parent');
});

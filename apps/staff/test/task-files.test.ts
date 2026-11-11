import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  MAX_FILE_BYTES,
  contentTypeFor,
  fileProblem,
  formatBytes,
  isVideo,
  storagePath,
} from '../src/lib/task-files.ts';

test('school file types are accepted, by browser type or by extension', () => {
  assert.equal(contentTypeFor({ name: 'sheet.pdf', type: 'application/pdf' }), 'application/pdf');
  // Some browsers send no type for Office files: the extension decides.
  assert.equal(
    contentTypeFor({ name: 'Lesson 4.PPTX', type: '' }),
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  );
  assert.equal(contentTypeFor({ name: 'photo.heic', type: 'image/heic' }), 'image/heic');
  assert.equal(contentTypeFor({ name: 'clip.mov', type: '' }), 'video/quicktime');
});

test('other files are refused with a reason a teacher can read', () => {
  assert.equal(contentTypeFor({ name: 'setup.exe', type: 'application/x-msdownload' }), null);
  assert.equal(
    fileProblem({ name: 'setup.exe', type: 'application/x-msdownload', size: 10 }),
    'setup.exe isn’t a file type Chom takes.',
  );
  assert.equal(
    fileProblem({ name: 'big.mp4', type: 'video/mp4', size: MAX_FILE_BYTES + 1 }),
    'big.mp4 is over 300 MB.',
  );
  assert.equal(
    fileProblem({ name: 'empty.pdf', type: 'application/pdf', size: 0 }),
    'empty.pdf is empty.',
  );
  assert.equal(
    fileProblem({ name: 'ok.pdf', type: 'application/pdf', size: MAX_FILE_BYTES }),
    null,
  );
});

test('videos are spotted, so the form can suggest a link instead', () => {
  assert.equal(isVideo({ name: 'clip.mp4', type: 'video/mp4' }), true);
  assert.equal(isVideo({ name: 'notes.pdf', type: 'application/pdf' }), false);
});

test('files go under <school>/<task>/ with a tidy, unique name', () => {
  const school = '97b09e91-1e3f-408e-9dde-66f434a04471';
  const task = 'a7305260-425a-4f15-9209-1b0178e9bb7c';
  const path = storagePath(school, task, 'Gr 11 Trig — worksheet (v2).pdf', 'abc');
  assert.equal(path, `${school}/${task}/abc-Gr-11-Trig-worksheet-v2.pdf`);
  // Exactly three parts, as the storage access rules expect.
  assert.equal(path.split('/').length, 3);
  assert.equal(storagePath(school, task, '/../../etc', 'x').split('/').length, 3);
  assert.equal(storagePath(school, task, '###', 'x'), `${school}/${task}/x-file`);
});

test('sizes read naturally', () => {
  assert.equal(formatBytes(2_400_000), '2.3 MB');
  assert.equal(formatBytes(300), '1 KB');
});

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { answerStudyQuestion } from '../src/lib/ask-chom.ts';

function questionRequest(body: unknown, origin = 'https://chom.co.za', ip = 'test-learner') {
  return new Request('https://chom.co.za/api/ask-chom', {
    method: 'POST',
    headers: {
      origin,
      'content-type': 'application/json',
      'x-vercel-forwarded-for': ip,
    },
    body: JSON.stringify(body),
  });
}

test('rejects cross-origin requests and invalid questions before contacting a model', async () => {
  const cases = [
    questionRequest(
      { subject: 'Mathematics', question: 'Explain fractions' },
      'https://elsewhere.test',
    ),
    questionRequest({ subject: 'Unknown', question: 'Explain fractions' }),
    questionRequest({ subject: 'Mathematics', question: '   ' }),
    questionRequest({ subject: 'Mathematics', question: 'a'.repeat(1001) }),
    questionRequest(null),
    questionRequest({ subject: {}, question: [] }),
  ];
  for (const request of cases) {
    const response = await answerStudyQuestion(request, undefined);
    assert.ok([400, 403].includes(response.status));
  }
});

test('missing gateway authentication returns an honest unavailable message', async () => {
  const response = await answerStudyQuestion(
    questionRequest({ subject: 'Life Sciences', question: 'What is photosynthesis?' }),
    undefined,
  );
  assert.equal(response.status, 503);
  assert.equal(typeof (await response.json()).error, 'string');
});

test('successful answers are returned, empty provider answers are handled, bursts are limited', async (t) => {
  const mockFetch = t.mock.method(globalThis, 'fetch', async () =>
    Response.json({
      choices: [{ message: { content: '  Plants turn light into chemical energy.  ' } }],
    }),
  );
  const body = { subject: 'Life Sciences', question: 'What is photosynthesis?' };
  const first = await answerStudyQuestion(questionRequest(body), 'test-token');
  assert.equal(first.status, 200);
  assert.deepEqual(await first.json(), { answer: 'Plants turn light into chemical energy.' });
  assert.equal(first.headers.get('cache-control'), 'no-store');

  mockFetch.mock.mockImplementation(async () => Response.json({ choices: [] }));
  const empty = await answerStudyQuestion(
    questionRequest(body, undefined, 'empty-answer'),
    'test-token',
  );
  assert.equal(empty.status, 503);

  mockFetch.mock.mockImplementation(async () => {
    throw new Error('network down');
  });
  const failed = await answerStudyQuestion(
    questionRequest(body, undefined, 'network-error'),
    'test-token',
  );
  assert.equal(failed.status, 503);

  mockFetch.mock.mockImplementation(async () =>
    Response.json({ choices: [{ message: { content: 'Answer' } }] }),
  );
  for (let count = 1; count < 5; count++) {
    assert.equal((await answerStudyQuestion(questionRequest(body), 'test-token')).status, 200);
  }
  const callsBefore = mockFetch.mock.callCount();
  const limited = await answerStudyQuestion(questionRequest(body), 'test-token');
  assert.equal(limited.status, 429);
  assert.equal(mockFetch.mock.callCount(), callsBefore);
});

// Copies the HTML prototypes (static/) into the web app's public folder before each
// build, so one Vercel project serves everything:
//   /app/      student prototype (the dashboard students land on after onboarding)
//   /teacher/  teacher prototype
//   /shared/   sample data and styles both prototypes use
// The copies are build output (git-ignored); edit the originals in static/.
import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const web = join(dirname(fileURLToPath(import.meta.url)), '..');
const repo = join(web, '..', '..');
const pub = join(web, 'public');

const copies = [
  ['static/site/app', 'app'],
  ['static/teacher-prototype', 'teacher'],
  ['static/prototype-data', 'shared'],
  // The learner prototype's font files sit next to the marketing page, and the
  // prototype refers to them as ../fonts. Served from /fonts on this app.
  ['static/site/fonts', 'fonts'],
];

for (const [from, to] of copies) {
  await rm(join(pub, to), { recursive: true, force: true });
  await mkdir(join(pub, to), { recursive: true });
  await cp(join(repo, from), join(pub, to), { recursive: true });
}

// Paths that differ now the prototypes live inside the app.
async function patch(file, replacements) {
  const path = join(pub, file);
  let html = await readFile(path, 'utf8');
  for (const [from, to] of replacements) html = html.replaceAll(from, to);
  await writeFile(path, html);
}

// "Sign out" really signs out.
await patch('app/index.html', [
  ['class="sign-out" href="../"', 'class="sign-out" href="/sign-out"'],
  ['<a class="button" href="../">Sign out</a>', '<a class="button" href="/sign-out">Sign out</a>'],
]);
// The teacher page is served at /teacher (no trailing slash), so make its own files
// absolute, and point its student links at /app/.
await patch('teacher/index.html', [
  ['href="teacher.css"', 'href="/teacher/teacher.css"'],
  ['src="teacher.js"', 'src="/teacher/teacher.js"'],
  ['href="/student/app/', 'href="/app/'],
]);

console.log('Copied prototypes into apps/web/public/{app,teacher,shared}');

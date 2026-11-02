// Builds the no-build static HTML in static/ into dist/. Output paths are
// unchanged so the existing Vercel projects keep working:
//   dist/student  ← public home page (/) + student prototype (/app/)
//   dist/teacher  ← teacher prototype, with the student build under /student/
import { mkdir, cp, rm } from 'node:fs/promises';

const shared = 'static/prototype-data';
const builds = [
  { source: 'static/site', target: 'dist/student' },
  { source: 'static/teacher-prototype', target: 'dist/teacher', withStudent: true },
];

for (const { source, target, withStudent } of builds) {
  await rm(target, { recursive: true, force: true });
  await mkdir(target, { recursive: true });
  await cp(source, target, { recursive: true });
  await cp(shared, `${target}/shared`, { recursive: true });
  if (withStudent) await cp('static/site', `${target}/student`, { recursive: true });
}

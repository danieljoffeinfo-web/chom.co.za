# Chom Learn HTML prototypes

Two static applications in one repository. No framework, dependencies or backend.

- `apps/student/index.html`: original learner dashboard, extended with My Subjects.
- `apps/teacher/`: teacher overview, subject resources, tasks, assignments and calendar.
- `packages/shared/`: shared sample school data, local persistence and subject UI styles.
- `scripts/build.mjs`: builds both independently deployable static directories.

Run `npm run build`. Serve `dist/teacher` or `dist/student` with any static server.

## Vercel projects

Both projects use this repository with the repository root as Root Directory.

| Project | Build command | Output directory |
|---|---|---|
| chom-co-za (existing learner) | `node scripts/build.mjs` | `dist/student` |
| chom-teacher (new teacher) | `node scripts/build.mjs` | `dist/teacher` |

The root vercel.json defaults to the existing learner deployment. For the teacher project, override Output Directory to `dist/teacher` in its project settings, or deploy the prebuilt `dist/teacher` directory directly. The current teacher deployment uses static source upload of that directory; it is not automatically Git-linked.

## Preview behaviour

Teacher URL includes `/student/#subjects` so both views can demonstrate shared browser-only state. The existing learner URL has its own sample state because separate origins cannot share localStorage or IndexedDB. No school accounts, real submissions, messages or backend uploads exist. Uploaded files (10 MB maximum) are stored in IndexedDB on the current browser. Metadata and sample work are stored in localStorage. Clearing site data clears changes.

Sample profile, dates, classes, counts and resources are illustrative. The learner preview is Grade 10B; material assigned to 10A is intentionally absent. Downloadable sample resources are small text documents.

## Design reference

Primary: existing Chom student site, commit e861749. Preserve #2860f5 actions, #f7f7f8 canvas, white 22px rounded panels, system sans-serif, 224px sidebar and apricot supporting card.
Secondary: Google Classroom assignment screen (Refero 503f8c38-8c8f-46fd-bdfe-c2000c9f40c5) informs subject/class/due-date/marks fields; the monochrome UI style reference informs quiet dividers and restrained form surfaces only. No new illustration assets are required.

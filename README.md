# Chom Learn

One platform for students, teachers and parents across many schools. This repository is a monorepo: every app and shared package lives here, managed with [pnpm](https://pnpm.io) workspaces and [Turborepo](https://turborepo.com).

## Layout

```
apps/                   Workspace apps (every folder here is picked up automatically)
  web/                  Next.js web app: teacher dashboard, school admin,
                        and the web version for students and parents
  mobile/               Expo (React Native) app for iOS and Android: one app,
                        the signed-in person's role picks the experience
packages/               Shared workspace packages (picked up automatically)
  api/                  The typed data client shared by web and mobile, with
                        TypeScript types generated from the database
  tokens/               Design tokens: colours, type, spacing, radius.
                        TypeScript for mobile, tokens.css for web
  tsconfig/             Shared TypeScript settings
static/                 No-build HTML, outside the workspace, deployed as-is
  site/                 Live static site: public home page (/) and the
                        student prototype (/app/). Deployed to chom.co.za
  teacher-prototype/    Static teacher prototype (design reference only)
  prototype-data/       Sample data used only by the static prototypes
supabase/               The database: migrations (structure and access rules),
                        test seed data and automated access tests
docs/
  decisions/            Architecture decision records (start with 0001)
scripts/
  build.mjs             Builds static/ into dist/
  gen-db-types.sh       Regenerates the database types (pnpm db:types)
  vercel-ignore.sh      Skips chom.co.za deploys when static/ didn't change
```

To add a shared package, create a folder under `packages/` with a `package.json` named `@chom/<name>`. No other registration is needed.

## Getting started

Requires Node 22+ and pnpm 10 (`corepack enable` installs the right version).

```bash
pnpm install
```

| Command             | What it does                                                                 |
| ------------------- | ---------------------------------------------------------------------------- |
| `pnpm dev:web`      | Run the web app at http://localhost:3000                                     |
| `pnpm dev:mobile`   | Start Expo. Open on a phone with Expo Go, or an iOS/Android simulator        |
| `pnpm typecheck`    | Type-check every package                                                     |
| `pnpm lint`         | ESLint for web and mobile (no warnings allowed), plus the design-token check |
| `pnpm test`         | Unit tests (for example the check that blocks secret keys in apps)           |
| `pnpm format`       | Format everything with Prettier                                              |
| `pnpm format:check` | Check formatting without changing files (what CI runs)                       |
| `pnpm build`        | Production build of the web app                                              |
| `pnpm build:site`   | Build the static site into `dist/` (no install needed)                       |
| `pnpm db:start`     | Start a local Supabase (needs Docker); applies migrations and test data      |
| `pnpm db:test`      | Run the database access and integrity tests                                  |
| `pnpm db:reset`     | Rebuild the local database from scratch                                      |
| `pnpm db:types`     | Regenerate `packages/api/src/database.types.ts` after changing the schema    |
| `pnpm db:stop`      | Stop the local Supabase                                                      |

ESLint fails if code imports a package its own `package.json` doesn't list. `node_modules` is flat (Expo needs this), so without that rule an undeclared package would quietly work locally and break elsewhere.

## Secrets and environment files

Never commit `.env` files. Every `.env` and `.env.*` file is ignored by git, and CI fails if one is force-added. To document which settings an app needs, commit a `.env.example` next to it with the variable names and no real values.

## Database

Supabase (PostgreSQL), as decided in [ADR 0001](docs/decisions/0001-database-platform.md). Production is the Supabase project `chom.co.za` (eu-west-1, Ireland).

**Structure.** Every change to the database is a numbered file in `supabase/migrations/`, reviewed like code. Never change the production database through the dashboard.

**Many schools, one database.** Every school-scoped row carries `school_id`. Foreign keys include `school_id`, so the database itself refuses links across schools, for example enrolling a learner in another school's class.

**Core tables.**

| Table                             | Holds                                                                                                                                                                                     |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `curricula`                       | Curricula (IEB now; CAPS, Cambridge later as rows, not code)                                                                                                                              |
| `curriculum_subjects`             | Each curriculum's official subjects: grades, category, language level, compulsory, externally examined, counts toward the certificate. Cambridge levels (IGCSE, AS, A) sit on the subject |
| `curriculum_subject_aliases`      | Other names for a subject ("Maths Lit", "CAT"), valid for a grade range. Never ambiguous within a grade                                                                                   |
| `curriculum_subject_rules`        | Subject combination rules (e.g. Mathematics or Mathematical Literacy, never both). Stored now, enforced when subject choice is built                                                      |
| `curriculum_subject_rule_members` | The subjects each rule applies to                                                                                                                                                         |
| `schools`                         | Each school                                                                                                                                                                               |
| `academic_years`                  | A school's years and the curriculum it follows that year; one is current                                                                                                                  |
| `profiles`                        | One row per person, across schools. Linked to a login once they have one                                                                                                                  |
| `school_memberships`              | A person's role at a school (student, teacher, parent, school admin). One person can hold several                                                                                         |
| `guardianships`                   | Which parent is linked to which child                                                                                                                                                     |
| `subjects`                        | The subjects a school offers, usually linked to the curriculum catalogue                                                                                                                  |
| `classes`                         | Classes per school year: a grade number for sorting plus a free-text name (10B, 10LSI, ...)                                                                                               |
| `class_subjects`                  | A subject taught to a class                                                                                                                                                               |
| `teaching_allocations`            | Which teacher teaches it                                                                                                                                                                  |
| `enrolments`                      | Which learner is in which class                                                                                                                                                           |

**The IEB catalogue** (42 subjects, 14 aliases, 4 combination rules) comes from Chom's "Available IEB Subjects" spreadsheet, which cites IEB's NSC requirements. To match a name from a spreadsheet or Ednana to the official subject, use `resolve_curriculum_subject('IEB', 'Maths Lit', 11)`. It checks official names first, then aliases, and respects grades: "Science" means Natural Sciences in Grades 8-9 and Physical Sciences in Grades 10-12.

Every table keeps an `ednana_id` where relevant, for the future Ednana sync. Staff accounts and the audit log live in the `private` schema, which the apps can never reach.

**Access rules.** Row-level security, enforced by the database on every request:

- Nobody sees anything from a school they don't belong to. Only active memberships count.
- Students see their own details, their school's subjects and their classes, but not their classmates.
- Teachers see the classes they teach, the learners in them and those learners' parents.
- Parents see their own children, and those children's classes and teachers.
- School admins see and manage everything in their own school.
- Everyone can change their own preferred name. Changes to who belongs where are recorded in an audit log.

**Adding a table.** In its migration, open it to the apps with one line, then write its access rules:

```sql
select private.expose_table('public.my_table', 'select, insert, update, delete');
```

`expose_table` switches on row-level security, removes default grants and never opens anything to signed-out visitors. A guardrail test fails CI if any table lacks row-level security or access rules, or is reachable signed out.

**Tests.** `supabase/tests/` checks school isolation, what each role can see and change, and data integrity, against two fake schools in `supabase/seed.sql`. The seed is for local and CI only; it is never loaded into production.

**Types.** After changing the schema, run `pnpm db:types` and commit the result. CI fails if the types are out of date.

## Design tokens

`packages/tokens` is the single source of truth for the Chom look: navy `#282B4A` as the main colour, vanilla `#EEEBDA` as the background, Inter Tight, light mode by default and dark mode opt-in.

- Mobile imports the values directly: `import { colors, space } from '@chom/tokens'`.
- Web imports `@chom/tokens/tokens.css` and uses the `--chom-*` CSS variables.
- `pnpm lint` fails if `tokens.css` and `src/index.ts` disagree, so change both together.

## Deployments

| What                                        | Where                                    | How                                                                                                                                                                                                  |
| ------------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Static site (home page + student prototype) | chom.co.za (Vercel project `chom-co-za`) | Root `vercel.json`: skips dependency install, runs `node scripts/build.mjs`, serves `dist/student`. Skips the deploy when nothing in `static/` or its build changed since the last successful deploy |
| Teacher prototype                           | Vercel project `chom-teacher`            | Same build, output directory `dist/teacher`                                                                                                                                                          |
| Web app                                     | Not deployed yet                         | Will be a new Vercel project with Root Directory `apps/web`                                                                                                                                          |
| Mobile app                                  | Not published yet                        | Will be built and submitted with Expo EAS                                                                                                                                                            |

## Checks

GitHub Actions (`.github/workflows/ci.yml`) runs on every pull request and every push to `main`, with a read-only token:

1. No `.env` files committed
2. Install from the lockfile
3. Formatting (Prettier)
4. Type check
5. Lint (ESLint and the design-token check)
6. Unit tests
7. Web build
8. iOS and Android bundles
9. Static site build

A second job starts a local Supabase, applies every migration and the test seed, runs the database tests in `supabase/tests/`, and checks that the generated database types are up to date.

Mobile images and fonts can be imported with either `import logo from './logo.png'` or `require('./logo.png')`. The types for both are committed in `apps/mobile/src/types/assets.d.ts`, so they type-check in CI as well as locally.

## Prototype notes

The static site and teacher prototype use sample data only. Changes are stored in the browser (localStorage and IndexedDB) and do not sync. The teacher prototype links to the student prototype at `/student/app/#subjects` so both can show shared browser-only state.

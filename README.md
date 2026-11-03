# Chom Learn

One platform for students, teachers and parents across many schools. This repository is a monorepo: every app and shared package lives here, managed with [pnpm](https://pnpm.io) workspaces and [Turborepo](https://turborepo.com).

## Layout

```
apps/                   Workspace apps (every folder here is picked up automatically)
  web/                  Next.js web app at chom.co.za: sign-in, onboarding and
                        the web version for students and parents
  staff/                Next.js staff dashboard at staff.chom.co.za, for teachers
                        and school admins. Its own Vercel project (chom-staff)
  mobile/               Expo (React Native) app for iOS and Android: one app,
                        the signed-in person's role picks the experience
packages/               Shared workspace packages (picked up automatically)
  api/                  The typed data client shared by web and mobile, with
                        TypeScript types generated from the database
  tokens/               Design tokens: colours, type, spacing, radius.
                        TypeScript for mobile, tokens.css for web
  tsconfig/             Shared TypeScript settings
static/                 No-build HTML prototypes, the design target for the app.
                        Copied into apps/web at build time and served at
                        chom.co.za/app (student) and chom.co.za/teacher
  site/                 Old static home page and the student prototype (app/)
  teacher-prototype/    Teacher prototype
  prototype-data/       Sample data used only by the static prototypes
supabase/               The database: migrations (structure and access rules),
                        test seed data and automated access tests
docs/
  decisions/            Architecture decision records (start with 0001)
  design/               Design spec shared by the learner and staff dashboards
scripts/
  build.mjs             Builds static/ into dist/
  gen-db-types.sh       Regenerates the database types (pnpm db:types)
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
| `pnpm dev:staff`    | Run the staff dashboard at http://localhost:3001                             |
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
| `school_groups`                   | A school, or a franchise of schools (e.g. Curro), sharing email domains and sign-in. A single school is a group of one                                                                    |
| `school_group_domains`            | A group's email domains and the only sign-in trusted for each (Microsoft with the school's tenant, or Google)                                                                             |
| `schools`                         | Each school, in a group                                                                                                                                                                   |
| `academic_years`                  | A school's years and the curriculum it follows that year; one is current                                                                                                                  |
| `profiles`                        | One row per person, across schools. Linked to a login once they have one                                                                                                                  |
| `school_memberships`              | A person's role at a school (student, teacher, parent, school admin). One person can hold several                                                                                         |
| `guardianships`                   | Which parent is linked to which child                                                                                                                                                     |
| `subjects`                        | The subjects a school offers, usually linked to the curriculum catalogue                                                                                                                  |
| `classes`                         | Classes per school year: a grade number for sorting plus a free-text name (10B, 10LSI, ...)                                                                                               |
| `class_subjects`                  | A subject taught to a class                                                                                                                                                               |
| `teaching_allocations`            | Which teacher teaches it                                                                                                                                                                  |
| `enrolments`                      | Which learner is in which class                                                                                                                                                           |
| `student_study_profiles`          | A student's study habits for a school year, from onboarding: session length, how and when they study                                                                                      |
| `student_subject_goals`           | A student's target percentage per subject, and up to 3 focus subjects                                                                                                                     |

**Signing in.** The roster decides who someone is: each membership carries the email the school knows them by. After every sign-in the app calls `link_my_account()`, which links the login to the one roster profile with that email, but only if the login proves it the way the school allows:

- A registered school domain (e.g. `curro.co.za`) only trusts that school's own sign-in: Microsoft from the school's tenant, or Google Workspace. A franchise registers its domain once for all campuses; the roster decides the campus.
- Any other email (parents, testing) only trusts a one-time email link or Google.
- It links nothing, and says why, when the email is on no roster, is on more than one profile, or the profile already has another login.

The Microsoft tenant check reads the `tid` claim Supabase stores for Microsoft logins; it must be confirmed against a real Microsoft sign-in before the first school goes live.

**Onboarding answers** (study habits, targets, focus subjects) can be seen by the student, their teachers, their parents and school admins, and changed only by the student. Goal changes are kept in the audit log.

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

| What                                                                                                | Where                                                         | How                                                                                                                                                                                                                                                                                                                       |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Web app: home page, sign-in, onboarding, and the HTML prototypes at `/app` (student) and `/teacher` | chom.co.za (Vercel project `chom-co-za`)                      | Root Directory `apps/web`, Next.js. Before each build, `apps/web/scripts/copy-prototypes.mjs` copies the prototypes from `static/` into `public/`. Needs `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (see `apps/web/.env.example`). Supabase Auth must allow `https://chom.co.za/auth/callback` |
| Staff dashboard for teachers and school admins                                                      | staff.chom.co.za (Vercel project `chom-staff`, region `dub1`) | Root Directory `apps/staff`, Next.js. Same Supabase settings as the web app. In production every other address (any `*.vercel.app`) is forwarded to staff.chom.co.za, because sign-in links only work when they start and end there. Supabase Auth must allow `https://staff.chom.co.za/auth/callback`                    |
| Database                                                                                            | Supabase project `chom.co.za`                                 | `.github/workflows/deploy-database.yml`: after CI passes on `main`, applies new files in `supabase/migrations/` to production with the pinned Supabase CLI. Never loads the seed. See below                                                                                                                               |
| Mobile app                                                                                          | Not published yet                                             | Will be built and submitted with Expo EAS                                                                                                                                                                                                                                                                                 |

### Database deploys

Merging a pull request that adds a migration is all it takes: once CI passes on `main`, the **Deploy database** workflow applies it to production. It always deploys the latest `main`, one deploy at a time, and only once CI has passed on that exact commit.

- It stops without changing anything if production has a migration the repo doesn't, which means someone changed the database outside the repo.
- Migrations already on `main` can't be edited, and a new migration must be newer than every migration on `main` (CI fails otherwise).
- To check what would be applied, run the workflow by hand from the Actions tab, on `main`. **Dry run** is ticked by default.
- **Database first, then the app.** Vercel deploys the apps as soon as a pull request merges, a minute or two before the migration lands. App code that needs a new table or function must not merge in the same pull request as its migration: merge the migration first, then the app change.

**One-time setup.** The workflow needs a Supabase access token, kept as a GitHub secret:

1. Create a token at [supabase.com/dashboard/account/tokens](https://supabase.com/dashboard/account/tokens), named `github-deploy-database`. If it offers scopes, limit it to the `chom.co.za` project.
2. In GitHub: **Settings → Environments → New environment**, named `productionchom`.
3. In that environment, under **Environment secrets**, add `SUPABASE_ACCESS_TOKEN` with the token.
4. Under **Deployment branches and tags**, choose **Selected branches and tags** and add `main`, so only merged code can use the token.
5. Optional: tick **Required reviewers** and add yourself, so each deploy waits for your click.

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

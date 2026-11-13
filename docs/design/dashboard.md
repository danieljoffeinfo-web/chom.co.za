# Dashboard design spec

The learner, staff and parent dashboards are one product, so they share one look. The learner dashboard (`static/site/app/index.html`) is the design source; the staff dashboard (`apps/staff`) and the parent dashboard (`apps/web`, under `/parent`) use a copy of its styles from `packages/dashboard`.

## Where the styles live

| File                                 | What it is                                                                                                                                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `packages/tokens/tokens.css`         | Colours, radius and spacing for every app. Light by default; `data-theme="dark"` on `<html>` switches to dark.                                                                       |
| `static/site/app/index.html`         | The learner dashboard, the design source.                                                                                                                                            |
| `packages/dashboard/dashboard.css`   | A copy of the learner dashboard's styles. Its colour names (`--bg`, `--ink` and so on) point at `@chom/tokens`.                                                                      |
| `packages/dashboard/app.css`         | Additions every Next.js dashboard needs: form sign-out, empty and coming-soon states, loading skeletons.                                                                             |
| `packages/dashboard/icons.svg`       | The learner dashboard's icons (Heroicons 2.2, MIT), used as `<Icon name="home" />`. Each app serves them at `/icons.svg`. After editing, run `pnpm --filter @chom/dashboard sprite`. |
| `apps/staff/src/app/staff.css`       | The few additions the staff dashboard needs. Keep it short.                                                                                                                          |
| `apps/web/src/app/parent/parent.css` | The few additions the parent dashboard needs: the bottom dock on phones, the sibling switcher, the consent screen.                                                                   |

When the learner dashboard's styles change, copy the change into `packages/dashboard/dashboard.css` too.

## Colour

Navy and vanilla are the base, with bright accents for fun. Light mode is the default; dark mode is opt-in from Settings.

| Role         | Light     | Dark      | Token               |
| ------------ | --------- | --------- | ------------------- |
| Background   | `#eeebda` | `#282b4a` | `--chom-background` |
| Card/surface | `#f7f5eb` | `#33375c` | `--chom-surface`    |
| Text         | `#282b4a` | `#eeebda` | `--chom-text`       |
| Muted text   | `#5f6178` | `#aba9b8` | `--chom-text-muted` |
| Lines        | `#dcd8c3` | `#464a70` | `--chom-border`     |
| Soft fill    | `#e4e0cb` | `#3c4068` | `--chom-subtle`     |
| Primary      | `#282b4a` | `#eeebda` | `--chom-primary`    |
| On primary   | `#eeebda` | `#282b4a` | `--chom-on-primary` |

Never write a colour value in app code. Use a token, or a prototype name that maps to one.

### Accents

Five bright accents make the dashboards playful. They are the same in both themes, and anything on an accent fill (text, icons, bars) is navy, `--chom-on-accent`.

| Accent    | Token                     | Value     | Typical use                                  |
| --------- | ------------------------- | --------- | -------------------------------------------- |
| Coral     | `--chom-accent-coral`     | `#ff7a59` | Due and late work, tests                     |
| Sunflower | `--chom-accent-sunflower` | `#ffc83d` | First stat tile, Focus tags, the hero's ring |
| Mint      | `--chom-accent-mint`      | `#3ccf9a` | Done, ticked tasks, progress                 |
| Sky       | `--chom-accent-sky`       | `#4fb3ff` | Later dates, calendar                        |
| Lilac     | `--chom-accent-lilac`     | `#a78bfa` | Notices, the learner's own tasks             |

A part picks its accent with a `.tone-coral` (`-sunflower`, `-mint`, `-sky`, `-lilac`) class and reads it as `--tone`. Soft fills mix it into the card: `color-mix(in srgb, var(--tone) 24%, var(--card))`. Stat tiles and class cards take their accents in turn by position. Accents never stand in for a subject.

### Subject colour

Every subject has one fixed colour and icon, picked by its name (`subjectStyle()` in `packages/dashboard/src/subject-icon.ts`; the learner dashboard keeps a copy of the table). The same subject looks the same on all three dashboards, in every class.

| Family            | Subjects                                     | Token                              | Light     | Dark      |
| ----------------- | -------------------------------------------- | ---------------------------------- | --------- | --------- |
| Maths             | Mathematics, Maths Literacy                  | `--chom-subject-maths`             | `#2563eb` | `#60a5fa` |
| English           | English                                      | `--chom-subject-english`           | `#7c3aed` | `#a78bfa` |
| Language          | Afrikaans, isiZulu and other languages       | `--chom-subject-language`          | `#db2777` | `#f472b6` |
| Life Orientation  | Life Orientation                             | `--chom-subject-life-orientation`  | `#16a34a` | `#4ade80` |
| Physical sciences | Physical Sciences                            | `--chom-subject-physical-sciences` | `#0284c7` | `#38bdf8` |
| Life sciences     | Life Sciences, Natural Sciences              | `--chom-subject-life-sciences`     | `#0d9488` | `#2dd4bf` |
| Commerce          | Accounting, Business Studies, Economics, EMS | `--chom-subject-commerce`          | `#d97706` | `#fbbf24` |
| Humanities        | Geography, History                           | `--chom-subject-humanities`        | `#ea580c` | `#fb923c` |
| Technology        | IT, CAT, EGD, Technology                     | `--chom-subject-technology`        | `#4f46e5` | `#818cf8` |
| Arts              | Visual Arts, Drama, Music, Design            | `--chom-subject-arts`              | `#c026d3` | `#e879f9` |

The icon on the fill is `--chom-on-subject` (white in light, navy in dark). Subject colours fill subject badges and may tint a card that is about one subject (`.subject-tint`, with the family class) and draw its goal ring. Never use them on text or buttons. Squares mean subjects; circles mean people.

## Type

Inter Tight, from Google Fonts (via `next/font` in the apps). Base size 14px.

- Page hero (`.cd-title`): very large, heavy, tight letter spacing. No greeting: the person's name and today's one fact. "Amara, 3 tasks on today’s list." / "Sizwe, 2 tasks due this week." / "Amara is focusing on Mathematics." (parents read about their child). One lede line under it says what's next.
- Date line (`.cd-label` above the hero): "Thursday 13 November", plus " · Term 4, Week 6" where the term is known.
- Label above a heading (`.cd-label`): the section name, in sentence case, e.g. "My classes".
- Section heading (`.cd-head h2`): "Your classes" / "What you teach".

## Layout

- **Sidebar** (`.sidebar`, 248px): wordmark, school card, a labelled main navigation, a secondary navigation (Settings), then Sign out and a footer line at the bottom. Below 900px it becomes a slide-in menu with a dimmed overlay.
- **Quick-actions dock** (`.quick-actions`): floating at the bottom right; below 900px it sits at the top right of the page.
- **Bottom tabs** (`.tab-dock`): below 900px only. The main sections, Home first, labels always shown. On the learner and staff dashboards the last tab, More, opens the sidebar as a menu.
- **Page** (`.page`): up to 1500px wide. Dashboard home pages use `.cd`, which is up to 1180px.
- **Other pages** start with `.view-header` (an `h1` and one line of intro).

## Components

| Component      | Class                                                                        | Used for                                                                                                           |
| -------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Hero and stats | `.cd-top`, `.cd-hero`, `.cd-stats`, `.cd-stat`, `.cd-stat-icon`, `.cd-meter` | A navy band with confetti: date, headline, lede, and the numbers as accent tiles (an icon, and a bar for “4 of 6”) |
| Subject badge  | `.subject-badge` (`<SubjectBadge name=… />`)                                 | A subject's fixed colour and icon, beside its name                                                                 |
| Bottom tabs    | `.tab-dock`                                                                  | The main sections on phones                                                                                        |
| Section        | `.cd-section`, `.cd-head`                                                    | A labelled block with an optional "See all" link; the label is a pill in the section's `.tone-*`                   |
| Class card     | `.cd-classes`, `.cd-class`, `.cd-avatar`, `.cd-next`                         | One subject and class                                                                                              |
| Panel          | `.panel`, `.panel-head`                                                      | Lists and tables                                                                                                   |
| Content card   | `.content-card`                                                              | Settings and single blocks of content                                                                              |
| Notice         | `.notice`, `.info-strip`                                                     | One line of context, e.g. what's coming (a lilac strip)                                                            |
| Empty state    | `.empty-message`                                                             | Nothing here yet, and coming soon; its icon sits in a bright blob                                                  |
| Buttons        | `.button`, `.button.secondary`, `.text-button`                               | Actions and "See all" links                                                                                        |
| Switch         | `.switch-row`                                                                | A setting with a label, a line of help and a checkbox                                                              |

## Navigation

| Learner dashboard                                                                | Staff dashboard                                                     | Parent dashboard                                     |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ---------------------------------------------------- |
| Home, My subjects, Study with Chom, My tasks, Assignments, My results, Timetable | Home, My classes, Set work, Calendar, Analytics, Messages, Co-pilot | Home, Academics, Sport, Future, Messages (per child) |
| School life, Messages, Settings                                                  | Settings                                                            | Account                                              |

Phone tabs (below 900px): learner Home, Subjects, Tasks, Study, More; staff Home, Classes, Set work, Messages, More; parent Home, Academics, Sport, Future, Messages.

The parent dashboard is mobile-first: below 900px the sidebar is hidden and the five sections are the bottom tabs. A sibling switcher sits at the top of every page and keeps the parent in the same section when they switch child.

## Writing

Plain, warm and short. Say what something does for the person, not how it works. Pages that aren't built yet say "Coming soon" and list, in a line each, what they will do.

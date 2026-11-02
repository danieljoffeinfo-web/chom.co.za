# ADR 0001: Managed Supabase (PostgreSQL) as the database and backend platform

| | |
|---|---|
| **Status** | Proposed: pending the sign-offs in [section 9](#9-sign-offs-before-this-is-accepted) |
| **Date** | 2 November 2026 |
| **Decision owner** | [NAME, ROLE] |
| **Applies to** | Student, teacher and parent apps (web, iOS, Android) and all backend services |
| **Review by** | 2 November 2027, or sooner if a trigger in [section 8](#8-when-to-revisit-this-decision) occurs |

---

## 1. Summary

Chom Learn will use **Supabase's managed platform** as its database and core backend: PostgreSQL, authentication, file storage, realtime messaging, background jobs and serverless functions.

- **One Supabase project per environment** (development, staging, production). The student, teacher and parent apps all share the same project in each environment.
- **One database for all schools.** Every school's records are tagged with that school, and access is enforced inside the database by PostgreSQL row-level security.
- **Hosted in a European region**, because Supabase has no South African region today. Section 6 sets out how this is handled under POPIA.

The database is standard PostgreSQL. Nothing about the data is tied to Supabase, and section 7 documents how to move to another host, including one inside South Africa.

## 2. Context

### What we are building

- Three experiences, for students, teachers and parents, delivered as web apps and one native iOS and Android app. A single person can hold more than one role, for example a teacher who is also a parent.
- About **90 schools** and **80,000 daily active users** (about 890 users per school), with growth expected.
- Data that is highly **relational**: schools, classes, subjects, enrolments, timetables, tasks, assignments, submissions, results, attendance, guardianships and messages.
- **Teacher–parent messaging** in the app, and parent notifications by push, email and WhatsApp (by opt-in).
- **Heavy AI use** ("Study with Chom"), metered per user and per school.
- **Two billing layers**: schools pay for Chom, and students or parents can buy add-on features.
- **Nightly sync from Ednana**, the schools' existing administration system, which stays the source of truth for learners, classes, guardians and timetables.

### Requirements for the platform

1. **Strict data separation**, enforced by the database itself rather than relying on each app to filter correctly. Almost every user is a minor.
2. A **relational database** that supports reporting, constraints and transactions.
3. **Authentication** for three roles, with one person able to hold several, and support for mobile apps.
4. **Private file storage** for homework submissions.
5. **Realtime** delivery for messaging.
6. **Background jobs and queues** for notifications, summaries and the Ednana sync.
7. **Capacity** for the school-day peak (estimate in section 5).
8. **Operable by a small team**: no dedicated infrastructure staff at launch.
9. **No lock-in at the data layer**, with a documented exit.
10. **A defensible position under POPIA** for children's personal information.

## 3. Decision

### Platform

Use managed Supabase on a paid plan with point-in-time recovery enabled in production.

| Need | Supabase component |
|---|---|
| Database | PostgreSQL, with row-level security on every table holding school or personal data |
| Connections at peak | Supavisor connection pooler |
| Sign-in | Supabase Auth (parents by emailed or texted code, teachers by email and later Google or Microsoft sign-in, students by a method to be agreed with schools) |
| Files | Supabase Storage, private buckets only, opened through short-lived signed links |
| Messaging | Supabase Realtime, used for messages only and opened only while the messages screen is in use |
| Privileged work | Edge Functions: AI gateway, notifications, billing webhooks, Ednana sync |
| Scheduled work | `pg_cron` and Supabase Queues |

### Data model principles

- Every school-scoped table carries a `school_id`, and every row-level security policy checks it.
- Roles are stored as a list per person, not one value per account.
- Parents are linked to learners through a guardianship table, which is the basis of every parent-facing access rule.
- Records imported from Ednana keep Ednana's identifier, and Chom never edits fields that Ednana owns.
- An append-only audit log records access to and changes of sensitive records (results, messages, guardianship).

### Alongside Supabase

These are not alternatives to Supabase. They cover work Supabase isn't designed for:

| Service | Purpose | Personal data? |
|---|---|---|
| **Upstash Redis** | Rate limits and AI usage quotas (per user, per school, short bursts), and limits on login and one-time-code attempts | **No.** Counters keyed by internal ID only. Names, messages and marks are never stored here. |
| **Vercel** | Hosting for the web apps and the public site | Session traffic only |
| **Expo (EAS)** | Native app builds, updates and push delivery through Apple and Google | Device tokens |
| **Anthropic (Claude API)** | AI tutor | Learner prompts. Minimised and subject to section 6 |

## 4. Alternatives considered

| Option | Data in South Africa? | Why it was not chosen |
|---|---|---|
| **AWS in Cape Town** (managed PostgreSQL, Cognito, S3, Lambda, API Gateway) | Yes | Meets residency directly, but means building and operating six or more services that Supabase provides together. That would need dedicated DevOps capacity and delay launch by months. **This is the planned destination if in-country hosting becomes mandatory** (section 7). |
| **Azure, South Africa regions** | Yes | Similar effort to AWS. Worth revisiting only if schools require Microsoft-based sign-in and hosting. |
| **Supabase self-hosted on AWS Cape Town** | Yes | Keeps the same tools with data in South Africa, but upgrades, backups, scaling and security patching become our job. Kept as the first fallback. |
| **Firebase (Firestore)** | — | A document database is a poor fit for heavily relational school data and reporting. Access rules live in a separate language rather than in the database, and leaving later means rewriting the data model. |
| **PostgreSQL elsewhere plus our own auth and API** (for example Neon or RDS with a custom backend) | Depends on host | We would have to build and secure authentication, file storage and realtime ourselves, which brings more risk and no gain at this stage. |

## 5. Capacity assumptions

These figures set the starting instance size and are reviewed after the first full school term.

| Assumption | Value |
|---|---|
| Schools | ~90 |
| Daily active users | ~80,000 |
| Share active in the busiest hour | ~40% |
| Requests per user session | ~30 |
| Average load in the busiest hour | ~270 requests/second |
| Burst allowance (07:30, first break, home time) | 3–5× |
| **Design peak** | **~1,000–1,500 requests/second** |

A correctly indexed PostgreSQL instance behind a connection pooler handles this. The constraints are:

- every query filters on an indexed column;
- each screen loads in as few requests as possible;
- live connections are used for messaging only.

AI traffic peaks at a different time (after school and during exams) and is limited by quotas in Redis rather than by database capacity.

**Scaling path, in order:**
1. Tune queries.
2. Move to a larger instance.
3. Add read replicas.
4. Add caching of non-personal data.

None of these requires changing the data model.

## 6. Data residency and POPIA

> **This section records our current position. It is not legal advice and must be confirmed by a POPIA practitioner before this ADR is accepted.**

### Where the data will be

- Supabase does not currently list a South African region. [Supabase regions](https://supabase.com/docs/guides/platform/regions) · [open request for a Cape Town region](https://github.com/orgs/supabase/discussions/34614)
- Production will use a European region: **[eu-west-1 Ireland / eu-west-2 London / eu-central-1 Frankfurt]**. Choose by measured latency from South African schools, and confirm the region is offered when the project is created.
- Expected added latency from South Africa is about 150–180 ms per request. It is mitigated by on-device caching (also needed for load-shedding and data costs), CDN-served app files and fewer requests per screen.

### Our position

- **Hosting abroad is allowed with safeguards.** POPIA has no blanket rule that personal information must stay on servers in South Africa. Section 72 permits a transfer abroad if one of its conditions is met, for example binding agreements giving adequate protection, consent, or necessity for a contract. [Michalsons](https://www.michalsons.com/focus-areas/privacy-and-data-protection/transfers-of-personal-information-outside-south-africa) · [CMS](https://cms.law/en/zaf/legal-updates/Managing-cross-border-data-transfers)
- **Every learner is a child under POPIA.** POPIA treats everyone under 18 as a child, so almost every learner record is children's personal information. Processing it needs a lawful basis under section 35, usually the prior consent of a competent person (a parent or guardian). *Counsel to confirm the basis we rely on.*
- **Who is responsible for what.** For school-provided features, each school is expected to be the **responsible party** and Chom an **operator** acting on the school's instructions, under a written operator agreement with each school (section 21). For add-ons bought directly by families, Chom is likely the responsible party. *Counsel to confirm.*
- **Cross-border transfer is already unavoidable.** The AI tutor sends learner prompts to a provider outside South Africa, so the safeguards above are needed whatever happens with the database. Hosting the database in Europe uses the same framework.

### Sub-processors to list in the privacy notice

| Sub-processor | Role | Data location |
|---|---|---|
| Supabase | Database, auth, storage, functions | [region chosen above] |
| Anthropic | AI tutor | [confirm from agreement] |
| Vercel | Web hosting | [confirm] |
| Upstash | Rate limiting (no personal data) | [confirm] |
| Expo, Apple, Google | App delivery and push notifications | [confirm] |
| Meta (WhatsApp Business) | Parent notifications, opt-in | [confirm] |
| [Email provider] | Parent notifications, opt-in | [confirm] |
| RevenueCat and [payment gateway] | Add-on purchases | [confirm] |

### Safeguards we commit to

- Signed data processing agreements with every sub-processor, filed as our section 21 operator contracts.
- A privacy notice that names each sub-processor and the countries data goes to.
- Consent from parents or guardians recorded with a timestamp and version, plus records of notification opt-ins.
- Data minimisation for AI: no names or identifying details sent to the model unless a feature needs them.
- Encryption in transit and at rest, which is standard on the platform. Multi-factor sign-in for staff and school admins.
- A documented retention schedule and deletion process, including when a learner leaves a school.
- A breach response plan that meets POPIA's notification duties.

## 7. Exit plan

Because the data layer is standard PostgreSQL, leaving Supabase is a migration project, not a rewrite.

| What | How it moves |
|---|---|
| Schema, data and row-level security policies | Standard PostgreSQL dump and restore. The policies are plain SQL and kept in `supabase/migrations` in git. |
| User accounts | Exported from the auth schema. Password hashes are standard bcrypt. Sign-in by one-time code needs no password migration. |
| Files | Copied bucket by bucket from storage, which is S3-compatible. |
| Edge Functions | TypeScript. Ported to the target platform's functions or a small service. |
| Realtime | Replaced with the target platform's equivalent. Only messaging depends on it. |

**Destinations, in order of preference:**
1. Supabase self-hosted on AWS Cape Town (same tools).
2. Managed PostgreSQL on AWS Cape Town with replacement auth and storage.

**Rehearse the exit once a year** by restoring a production backup into a self-hosted environment, so the plan is proven rather than assumed.

## 8. When to revisit this decision

Reopen this ADR if any of these happen:

- A school, provincial education department or contract requires learner data to be stored in South Africa.
- The Information Regulator issues guidance that changes the position in section 6.
- Supabase launches a South African region. Move to it unless there is a good reason not to.
- Database CPU stays above 60% during the morning peak after query tuning and one instance upgrade.
- Supabase costs exceed the alternatives by a margin that justifies running our own infrastructure.
- A security incident or audit finding involves the platform.

## 9. Sign-offs before this is accepted

- [ ] **POPIA counsel** confirms the section 6 position for children's personal information hosted in Europe, and the responsible-party and operator split.
- [ ] **Schools and departments:** confirmed that none of the 90 schools, or their departments, require in-country hosting.
- [ ] **Region:** chosen from measured latency, and confirmed as available.
- [ ] **Agreements:** data processing agreements signed with Supabase and every sub-processor in section 6.
- [ ] **Supabase terms:** current certifications, backup and point-in-time recovery, and support terms confirmed for the chosen plan.
- [ ] **Decision owner** approves and changes the status to **Accepted**.

## Consequences

**Positive**
- One platform covers database, auth, storage, realtime and functions, so a small team can ship.
- Access rules are enforced in the database for every app and every client version.
- Standard PostgreSQL keeps the data portable and familiar to any developer.

**Negative, and accepted**
- Data is hosted in Europe until Supabase offers a South African region, which needs the section 6 safeguards and adds some latency.
- Row-level security must be written carefully and tested automatically. A wrong policy is a data leak. Every policy ships with tests, and the platform's security advisor runs in CI.
- Supabase bills authentication by monthly active users, which will be a material cost at this scale.
- Realtime has connection limits, so its use is restricted to messaging.

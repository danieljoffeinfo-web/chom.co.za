# Chom Learn — Parent Dashboard Spec

> Build spec. Build feature by feature in the order in §10. Where this doc says **Default**, it's a decision taken to unblock the build — change it here first if it changes. §14 records what is built and where the build differs from the sketch.

---

## 1. Purpose and principles

The parent dashboard is the main lever for parent buy-in, and parent buy-in is what keeps schools paying. Chom owns the parent ↔ school ↔ learner communication channel.

Parents check in briefly, mostly on a phone. Every screen answers three questions:

1. **Is my child okay?**
2. **What's coming up?**
3. **What can I do?**

Principles:

- **Mobile-first layout**, browser-first delivery (responsive web app; native app later).
- **Parents act, not just read.** Explain an absence, confirm availability, sign a slip, book a meeting. Every action is a reason to return.
- **Learner trust is protected.** Parents never see raw AI tutor transcripts. If teens think parents read every question, they stop using the tutor honestly.
- **Learner vs own baseline, never vs class.** No rankings, no peer comparisons.
- **Calm by default.** Status bands first, detail one tap away. Notifications are tiered (§7) so parents don't mute the app.
- **Multi-child.** Sibling switcher on every screen.
- **Same UI as the other dashboards.** The parent dashboard uses the shared dashboard look (`packages/dashboard`, see `docs/design/dashboard.md`).

---

## 2. Roles and permissions

### Roles

| Role           | Description                                                             |
| -------------- | ----------------------------------------------------------------------- |
| `parent`       | Guardian linked to one or more learners                                 |
| `learner`      | High school learner (Gr 8–12)                                           |
| `teacher`      | Subject teacher; marks, comments, tests, register (if in-Chom register) |
| `coach`        | **New role.** Manages teams, fixtures, training, selections, results    |
| `comms_admin`  | **New role.** Posts school news, events, permission slips               |
| `school_admin` | Owns rosters, guardian links, roles, integrations                       |

A user can hold several roles (e.g. teacher + coach).

### Parent visibility

| Parents see                                                       | Parents don't see                                  |
| ----------------------------------------------------------------- | -------------------------------------------------- |
| Marks, trends, status bands, readiness scores                     | Raw AI tutor chat transcripts or questions asked   |
| Topics studied, weak/strong topics                                | Peer comparisons, class rankings                   |
| Study time on platform (totals, trends, by subject, time of day)  | Other learners' data of any kind                   |
| Attendance (daily, per period, lates)                             | Counsellor/safeguarding detail marked confidential |
| Teacher comments marked parent-visible                            | Teacher-only notes                                 |
| Sport: teams, fixtures, training, selections, results             | University draft content (motivation letters etc.) |
| University application progress, APS, deadlines, checklist status |                                                    |
| School news, events, slips                                        |                                                    |

### Guardian rules

- Multiple guardians per learner (separated parents both get access).
- `school_admin` can **block** a specific guardian from a learner (court orders, custody restrictions). Blocked guardians see nothing about that learner and receive no notifications for them.
- Each guardian link has a `relationship` (mother, father, guardian, other) and `is_primary` flag (primary receives fee/admin comms where relevant).

### Learners turning 18

**Default:** when a Gr 12 learner turns 18, they get a prompt to confirm parent access. Access continues unless the learner declines. If declined, the parent keeps school news, events and calendar only; academic, attendance and university data are hidden. Learner can change this later in settings. (Confirm with POPIA counsel before launch.)

---

## 3. Linking and consent

### Flow

1. `school_admin` uploads the roster Excel (same import as learner onboarding / auto class allocation). Add columns: `guardian_1_name`, `guardian_1_email`, `guardian_1_phone`, `guardian_1_relationship`, `guardian_2_*` (optional).
2. System creates `guardian` records and `guardian_learner_links` (status `invited`).
3. Invite sent by email + WhatsApp with a one-time link (expires 14 days, resendable by admin).
4. Parent signs up / signs in (email + password or magic link; Microsoft/Google OAuth optional later). Phone verified via OTP (needed for WhatsApp digest + alerts).
5. **POPIA consent screen** at first login (blocking):
   - What data Chom processes about their child and why
   - What parents can and can't see (§2 table, plain language)
   - Consent to processing a child's personal information (POPIA s35)
   - Notification channel opt-ins (WhatsApp, email, push)
   - Store: consent version, timestamp, IP, user agent
6. Link status → `active`. Parent lands on Home.

### Edge cases

- Same guardian across siblings at the same school → one account, multiple links.
- Same guardian across schools (Curro group) → one account, learners from multiple tenants. RLS must allow cross-tenant reads **only** for that guardian's linked learners.
- Guardian email not supplied → admin can add later; learner can also request a guardian invite from their profile (admin approves).
- Consent version changes → parent re-consents at next login.
- Consent withdrawn → link status `consent_withdrawn`; parent sees school news only; admin notified.

### Acceptance criteria

- [ ] Roster import creates guardians + links without duplicates (match on email)
- [x] Parent cannot see any learner data before consent is recorded
- [x] Blocked guardian sees nothing for that learner, even via direct URL/API
- [x] Cross-tenant guardian sees only their own learners in each tenant

---

## 4. Navigation

Bottom nav (mobile) / side nav (desktop):

1. **Home**
2. **Academics**
3. **Sport**
4. **Future** (Gr 11–12 only; Gr 8–10 see a lighter version — §5.6)
5. **Messages**

Account, consent, notifications and linked children live behind the avatar / top-right menu. Sibling switcher sits at the top of every screen.

---

## 5. Features

### 5.1 Home

The 30-second view. Order on screen:

1. **Alerts banner** (only when present): same-day absence, safeguarding (routed via school), urgent slip deadline.
2. **Key stats row** (3 cards): Attendance % (term), Study time / day (vs learner's own 4-week avg), Overall readiness % (upcoming assessments).
3. **Weekly AI summary**: 2–3 sentences, generated from marks, readiness, study time, attendance, teacher comments. Tone: calm, specific, no blame. Regenerated weekly (Sunday) + on major events.
4. **This week timeline**: merged list of tests, assignment due dates, training, fixtures, school events, deadlines. Each item shows inline actions where relevant (Confirm availability, Sign slip).
5. **Subject status list**: each subject with band — `on_track`, `watch`, `needs_attention`, plus trend arrow.
6. **University card** (Gr 11–12 only): APS vs target, applications started, next deadline.
7. **School news**: latest 1–2 items.
8. **Ask Chom input** (v3).

**Default:** status bands on Home, raw marks one tap away in Academics.

**Status band logic (v1, tune later):**

- `needs_attention`: latest assessment < 50%, or drop ≥ 10 pts vs previous, or readiness < 40% for a test within 7 days
- `watch`: 50–59%, or drop 5–9 pts, or readiness 40–59% within 7 days
- `on_track`: otherwise
- Bands computed server-side, stored with the reason so the UI can explain "Why?"

### 5.2 Academics

Per subject:

- Marks history + trend chart (term and year)
- Upcoming assessments with readiness score (capped per existing readiness logic) and weak topics
- Topic breakdown: strong / weak topics from learner memory + assessment data
- Teacher comments (parent-visible only)
- Study time on platform for that subject

Study time view (all subjects):

- Daily / weekly totals, 4-week trend
- Breakdown by subject
- Time-of-day distribution (e.g. "mostly studies after 22:00")
- Compared only with learner's own baseline

**Study time definition:** active time in learning surfaces (tutor, notes, practice, past papers) with an idle timeout of 5 min. Background tabs don't count.

### 5.3 Attendance

Shown on Home (stat + alert) and as its own section inside Academics (or a sub-tab).

- Term % present, days absent, late arrivals
- Per-period absences (where the source supports periods)
- Calendar view with absence days marked
- Absence reasons and status: `unexplained`, `explained_by_parent`, `excused_by_school`

**Same-day absence alert:** when a learner is marked absent (first period or registration), parent gets an instant push + WhatsApp. Parent actions:

- Give a reason (sick, appointment, family, other + note)
- Upload a sick note / document
- Submission goes to the school admin / register teacher queue

**Data source — Default:** build an `AttendanceSource` adapter interface. v1 ships the **in-Chom register** (teacher marks class register in Chom, or admin bulk-uploads daily register CSV). Integrations with d6+, ADAM, Karri come later as adapters. Confirm what Curro uses before building any integration.

Acceptance criteria:

- [ ] Teacher can mark register per class/period in < 30 s for a class of 30
- [ ] Absence alert reaches parent within 5 min of being recorded
- [ ] Parent explanation appears in school's absence queue with attachment
- [ ] Attendance % recalculates correctly when an absence is excused

### 5.4 Sport and extracurriculars

Managed by `coach` role. Per learner:

- Teams the learner belongs to (sport, team name, age group)
- Training schedule (recurring sessions + one-offs, venue, time)
- Fixtures (opponent, home/away, venue, time, transport, kit notes)
- Selections (team sheet published by coach)
- Results
- Extracurriculars (clubs, societies, cultural) — same model, `activity_type`

Parent actions:

- **Confirm availability** for a fixture (available / unavailable + reason). Coach sees a live availability list.
- Add sessions/fixtures to their calendar.

Notifications: fixture changes and cancellations are same-day tier; selections and reminders go in the digest unless within 48 h.

Future hooks (not v1): highlight video uploads, athlete profile / CV, scouting and scholarship agency access, Chom-hosted tournaments.

### 5.5 School news, events and permission slips

Managed by `comms_admin`.

- **News posts**: title, body, image, audience (whole school / grade / class / team), publish date.
- **Events**: date, time, location, audience, add-to-calendar.
- **Permission slips / forms**: digital form attached to an event (e.g. Gr 11 camp). Fields configurable (consent checkbox, medical notes, emergency contact, payment reference text). Parent signs in-app (typed name + checkbox + timestamp). Admin sees completion list and can send reminders to non-responders.

Acceptance criteria:

- [ ] Audience targeting works (a Gr 9 parent never sees a Gr 11-only post)
- [ ] Slip completion list exports to CSV
- [ ] Reminder sends only to parents who haven't signed

### 5.6 Future (university and careers)

**Gr 11–12 (full):**

- **APS score**: live, calculated from latest marks, using SA APS conversion (7-point scale, best 6 subjects excluding LO; per-university variations configurable). Show vs requirement for each target course.
- **Target courses**: learner picks courses/universities; parent sees them.
- **Application tracker** per university: status (`not_started`, `in_progress`, `submitted`, `outcome_pending`, `accepted`, `waitlisted`, `rejected`), opening date, deadline.
- **Document checklist** per application: ID copy, Gr 11 results, latest report, motivation letter, portfolio (if required), proof of payment of application fee. Status per item.
- **NBT dates** and registration status.
- **Bursaries and scholarships**: list matched on course, marks, sport.
- **AI assistance (learner side)**: deadline reminders, checklist, feedback on motivation letters, portfolio planning (e.g. architecture). AI coaches and gives feedback; it doesn't write the application for them.
- **Parent sees**: progress, deadlines, checklist status, APS. **Not** draft content.

University dates and requirements are maintained in an admin-editable table (Chom-level), refreshed yearly.

**Gr 9:** subject choice guidance for Gr 10 (which subjects keep which courses open).
**Gr 8–10:** interests logged at sign-up, revisited yearly; light "possible pathways" view, no pressure.

### 5.7 Messages

- School announcements (from news) in a feed.
- Parent ↔ teacher messaging.

**Default:** Ask Chom answers parent questions first (v3). Until then, and for anything Ask Chom can't answer, parent can message the teacher directly. Teachers set office hours; messages outside hours are queued with an auto-reply. Teachers can close threads. No read receipts shown to parents.

- Parent-teacher meeting booking: teacher publishes slots, parent books (v2).

### 5.8 Ask Chom (parent AI)

Parent-facing assistant grounded **only** in that parent's linked learners' data plus school content (calendar, news, test scopes).

Examples:

- "What's on Thabo's Physical Sciences test on Friday?"
- "How can I help him with electric circuits?"
- "Has he missed any school this term?"
- "When is the UCT application deadline?"

Rules:

- Same visibility rules as §2. Never reveals tutor transcripts, other learners, or teacher-only notes.
- Retrieval filtered by tenant + learner IDs linked to that guardian (enforce at query level, not prompt level).
- Escalation: "Message teacher" handoff with the question pre-filled.
- Available in the app and by replying to the WhatsApp digest.

### 5.9 Account

- Linked children (view, request link to another child)
- Consent: view what was agreed, consent version, withdraw
- Notification preferences per tier and channel
- Language (English v1; Afrikaans and isiZulu later)
- Low-data mode toggle (no images, compressed charts)
- Calendar sync (subscribe link)

---

## 6. Weekly digest

The main engagement channel. Most parents will read this more than they open the app.

- Sent **Sunday 18:00 SAST** via WhatsApp (primary) and email.
- One digest per parent, covering all linked children.
- Contents per child: AI summary (2–3 sentences), attendance this week, study time vs baseline, one flag (top `needs_attention` item), next 3 dates (tests, fixtures, deadlines), outstanding actions (unsigned slips, unexplained absences).
- Deep links into the dashboard.
- WhatsApp: parent can reply to ask a question (routes to Ask Chom in v3; before that, auto-reply with link).

---

## 7. Notifications

### Tiers

| Tier         | Delivery                    | Events                                                                                                      |
| ------------ | --------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Instant**  | Push + WhatsApp immediately | Absence recorded, safeguarding alert (school-routed), emergency school notice                               |
| **Same day** | Push (batched hourly)       | Fixture change/cancellation, new teacher message, slip deadline within 24 h, selection within 48 h of match |
| **Digest**   | Sunday digest               | Everything else: marks posted, news, upcoming tests, study time, university reminders                       |

- Quiet hours 21:00–06:00 for same-day tier (instant tier ignores quiet hours).
- Parents can change channels per tier; can't disable instant-tier absence alerts without admin.
- All notifications stored in `notifications` table with delivery status per channel.

---

## 8. Data model (sketch)

Supabase/Postgres. All tables carry `school_id` (tenant) unless noted. RLS on every table. §14 says how the built tables map onto this sketch.

```
guardians
  id, user_id (auth.users), full_name, email, phone, phone_verified_at,
  preferred_language, created_at

guardian_learner_links
  id, guardian_id, learner_id, school_id, relationship, is_primary,
  status (invited|active|blocked|consent_withdrawn|learner_revoked),
  invited_at, activated_at, blocked_reason

consents
  id, guardian_id, learner_id, consent_version, granted_at,
  withdrawn_at, ip, user_agent

attendance_records
  id, school_id, learner_id, date, period (nullable), status
  (present|absent|late|excused), source (chom_register|csv|d6|adam|karri),
  recorded_by, recorded_at

absence_explanations
  id, attendance_record_id, guardian_id, reason, note,
  attachment_path, submitted_at, school_status (pending|accepted|rejected)

study_sessions
  id, school_id, learner_id, subject_id, surface (tutor|notes|practice|past_paper),
  started_at, ended_at, active_seconds

subject_status
  id, school_id, learner_id, subject_id, band, reason, computed_at

teams
  id, school_id, sport, name, age_group, activity_type (sport|club|cultural)

team_members
  team_id, learner_id, role

team_coaches
  team_id, user_id

training_sessions
  id, team_id, starts_at, ends_at, venue, recurrence_rule, notes, cancelled

fixtures
  id, team_id, opponent, home_away, venue, starts_at, transport, kit_notes,
  status (scheduled|changed|cancelled|played), result_us, result_them

fixture_availability
  fixture_id, learner_id, guardian_id, available, reason, updated_at

selections
  fixture_id, learner_id, position, published_at

news_posts
  id, school_id, title, body, image_path, audience_type, audience_ids,
  publish_at, author_id

events
  id, school_id, title, starts_at, ends_at, location, audience_type,
  audience_ids, slip_form_id (nullable)

slip_forms
  id, school_id, event_id, fields (jsonb), due_at

slip_responses
  id, slip_form_id, learner_id, guardian_id, answers (jsonb),
  signed_name, signed_at

university_targets
  id, learner_id, university_id, course_id, priority

applications
  id, learner_id, university_id, course_id, status, opened_at,
  deadline_at, submitted_at, outcome

application_documents
  id, application_id, doc_type, status (missing|uploaded|verified), file_path

universities / courses / aps_rules / nbt_dates / bursaries
  Chom-level reference tables (no school_id), admin-editable

message_threads / messages
  thread between guardian(s) and teacher about a learner;
  school_id, learner_id, participants, closed_at

notifications
  id, recipient_user_id, learner_id, tier, type, payload (jsonb),
  channels (jsonb with per-channel status), created_at, read_at

weekly_summaries
  id, learner_id, week_start, summary_text, inputs (jsonb), generated_at
```

### RLS rules (parent)

- Parent can read learner-scoped rows only where an `active` `guardian_learner_links` row exists for `(auth guardian, learner_id)` and a non-withdrawn consent exists.
- `learner_revoked` links: parent reads only `news_posts`, `events` and calendar items for that learner's audience.
- `blocked` links: no access to anything for that learner.
- Parents never read `study_sessions` raw rows; expose aggregates via a view or RPC.
- AI tutor conversation tables: **no parent policy at all**.
- Cross-tenant: policies key on `learner_id` link, not on the parent's "current school".

Use the server-side service-role client only in background jobs (digest, band computation), never in request handlers that serve parents.

---

## 9. Integrations

| Integration                          | Version | Notes                                                   |
| ------------------------------------ | ------- | ------------------------------------------------------- |
| WhatsApp (Business API)              | v1      | Digest, instant alerts, invite links, reply-to-ask (v3) |
| Email                                | v1      | Invites, digest fallback                                |
| Web push                             | v1      | Instant + same-day tiers                                |
| Attendance: in-Chom register + CSV   | v1      | Behind `AttendanceSource` adapter                       |
| Calendar subscribe link (ICS)        | v2      | Per-parent feed, all linked children                    |
| Attendance: d6+, ADAM, Karri         | later   | Adapters; confirm Curro's system first                  |
| Microsoft / Google OAuth for parents | later   | Optional sign-in                                        |

---

## 10. Build order

Build one slice at a time. Each slice ships with RLS tests and seed data.

### v1 — core

1. Data model for guardians, links, consents + RLS + tests
2. Roster import extension (guardian columns) + invite flow (email + WhatsApp)
3. Parent sign-up, phone OTP, POPIA consent screen
4. App shell: nav, sibling switcher, mobile-first layout
5. Attendance: in-Chom register (teacher), CSV upload (admin), parent view
6. Instant absence alert + parent explanation flow
7. Study time tracking (`study_sessions`) + aggregates
8. Subject status bands (background job) + Academics view
9. Home screen (alerts, stats, timeline, subject list, AI summary)
10. Weekly digest (WhatsApp + email)

### v2 — school life

11. Coach + comms_admin roles
12. Sport: teams, training, fixtures, availability, selections, results
13. School news + events + audience targeting
14. Permission slips
15. Messages + teacher office hours + meeting booking
16. Calendar ICS feed
17. Notification tiers + preferences + quiet hours

### v3 — intelligence and future

18. Future tab: APS, targets, application tracker, checklist, NBT, bursaries
19. Gr 9 subject choice guidance; Gr 8–10 pathways view
20. Ask Chom (parent AI) in-app
21. Ask Chom via WhatsApp digest replies
22. Afrikaans + isiZulu UI, low-data mode
23. Attendance integrations (d6+/ADAM/Karri adapters)

---

## 11. Metrics

Track from v1 — these feed the Curro pitch and investor updates.

- **Parent weekly active rate** (headline KPI): % of linked parents who open the app or interact with the digest in a week
- Guardian activation rate (invited → consented)
- Digest open / click rate
- Median time from absence recorded → parent explanation
- Slip completion rate before deadline
- Fixture availability response rate
- Ask Chom questions per active parent (v3)

---

## 12. Open decisions

Defaults are set so the build isn't blocked. Revisit before launch.

| Decision                          | Default in this spec                                   |
| --------------------------------- | ------------------------------------------------------ |
| Status bands vs raw marks on Home | Bands on Home, marks one tap away                      |
| Direct teacher messaging          | Yes, with office hours; Ask Chom answers first from v3 |
| Gr 12 learners turning 18         | Access continues unless learner declines               |
| Attendance source                 | In-Chom register + CSV now; integrations later         |
| WhatsApp digest in v1             | Yes                                                    |
| Band thresholds                   | §5.1 values; tune with pilot school data               |
| Consent wording                   | Draft `2026-11-draft-1`; POPIA counsel to review       |

---

## 13. Out of scope (for now)

- Fee statements and payments
- Native mobile app (responsive web only)
- Athlete highlight video uploads and scouting agency access
- Corporate / job placement pathways
- Wellbeing check-ins and counsellor tooling

---

## 14. Build status and how it maps onto the schema

### Built

| Slice | What                                                     | Where                                                                                          |
| ----- | -------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 1     | Guardian link status, consent, channel opt-ins, RLS      | `supabase/migrations/20261103180000_parent_links_and_consent.sql`, tests in `09_parent_access` |
| 3     | POPIA consent screen (phone OTP not yet)                 | `apps/web/src/app/parent/consent`, wording in `apps/web/src/lib/parent/consent.ts`             |
| 4     | Shell: side nav, bottom dock on phones, sibling switcher | `apps/web/src/app/parent/(dashboard)`, shared look in `packages/dashboard`                     |
| —     | Home, Academics and Account with the data that exists    | One call: `public.my_parent_dashboard()` (`20261103180100_parent_dashboard.sql`)               |

Home shows what is known today (subjects, teachers, the child's targets, focus subjects and study habits) in the §5.1 layout. Attendance, study time, readiness, the timeline and bands slot in as slices 5–9 land. Sport, Future and Messages are "Coming soon" pages listing what they will do; Future already varies by grade.

### Differences from the §8 sketch

- **No separate `guardians` / `guardian_learner_links` tables.** A guardian is a `profiles` row with a `parent` membership at the school, as for every other role, and the link is `public.guardianships`, which gained `status`, `is_primary`, `invited_at`, `activated_at`, `blocked_reason` and `blocked_at`; `relationship` is now an enum. This keeps one record per person across roles (a teacher who is also a parent) and the existing cross-school foreign keys. Phone number and language go on the profile or membership when slices 2–3 need them.
- **`consents` is `public.parent_consents`**, keyed by the guardianship, with `public.parent_consent_versions` saying which version is current. The wording lives in the web app per version.
- **One rule gates everything.** Every parent access rule goes through `private.is_parent_of()`, which now requires an `active` link and a non-withdrawn consent to the current version. New learner-scoped tables get the same protection by using it.
- **Blocked guardians** don't see the link row either, so they can't learn the link exists. Blocking requires a reason; the time is recorded.
- **Cross-school**: rules key on the link, not on a "current school", so a parent sees each child at that child's school and nothing else there.
- **URLs**: `/parent/<child profile id>/<section>`; `/parent/account`; `/parent/consent`. A URL for a child the parent can't see is a 404.

### Not yet built in slices 1–4

- Roster import with guardian columns, invites by email and WhatsApp (slice 2).
- Phone number and OTP verification (slice 3).
- Notifying the school admin when consent is withdrawn (admins can see link status and consents today).
- The `learner_revoked` flow for learners turning 18 (the status exists; nothing sets it yet).

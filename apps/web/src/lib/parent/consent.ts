/**
 * The parent consent screen's wording, per version. The database
 * (public.parent_consent_versions) says which version is current; the screen shows
 * the matching text here and records that version. To change the wording, add a new
 * version here AND in a migration, never edit a published one.
 *
 * DRAFT: to be reviewed by POPIA counsel before the first school goes live
 * (docs/design/parent-dashboard.md, §3).
 */
export type ConsentText = {
  version: string;
  intro: string;
  processing: { title: string; points: string[] };
  canSee: string[];
  cannotSee: string[];
  agreement: string;
  rights: string;
};

export const CONSENT_TEXTS: Record<string, ConsentText> = {
  '2026-11-draft-1': {
    version: '2026-11-draft-1',
    intro:
      'Before you see your child’s information, here is what Chom does with it and what you agree to. It takes about a minute to read.',
    processing: {
      title: 'What Chom uses, and why',
      points: [
        'Your child’s name, school, grade, classes, subjects and teachers, from the school’s records, so we can show you the right information.',
        'Their marks, attendance, study time and the topics they work on, so you can see how they are doing against their own goals.',
        'Your name, email and phone number, so we can send you the weekly summary and urgent alerts such as an absence.',
        'Chom keeps this information in a secure database in Ireland (the EU). It is shared with your child’s school, and messages to you are sent through the WhatsApp and email services you choose below.',
      ],
    },
    canSee: [
      'Marks, trends and how ready they are for upcoming tests',
      'Strong and weak topics, and time spent studying on Chom',
      'Attendance, absences and late arrivals',
      'Teacher comments meant for parents',
      'Sport, school news, events and permission slips',
      'University applications, APS score and deadlines (Grades 11–12)',
    ],
    cannotSee: [
      'What your child asks Chom’s study tutor, or its answers',
      'Rankings or comparisons with other learners',
      'Any other learner’s information',
      'Teachers’ private notes, and confidential counselling records',
      'Drafts of university applications or motivation letters',
    ],
    agreement:
      'As my child’s parent or guardian, I consent to Chom processing my child’s personal information for these purposes, as required by section 35 of the Protection of Personal Information Act (POPIA).',
    rights:
      'You can withdraw this consent at any time under Account. You will then only see school news and events, and your child’s school will see that you withdrew it.',
  },
};

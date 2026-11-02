'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';

import {
  MAX_FOCUS_SUBJECTS,
  SESSION_LENGTHS,
  type SessionLength,
  STUDY_METHODS,
  STUDY_TIMES,
  type StudentContext,
  type StudyMethod,
  type StudyTime,
} from '@/lib/student';
import { createClient } from '@/lib/supabase/browser';

import styles from './onboarding.module.css';

type Answers = {
  focus: string[];
  targets: Record<string, string>;
  sessionLength: SessionLength | null;
  methods: StudyMethod[];
  times: StudyTime[];
};

const STEPS = ['welcome', 'focus', 'targets', 'length', 'methods', 'times'] as const;
type Step = (typeof STEPS)[number];

function toggle<T>(list: T[], value: T): T[] {
  return list.includes(value) ? list.filter((item) => item !== value) : [...list, value];
}

function validTarget(value: string | undefined): boolean {
  if (!value) return false;
  const n = Number(value);
  return Number.isInteger(n) && n >= 1 && n <= 100;
}

export function Onboarding({ student }: { student: StudentContext }) {
  const router = useRouter();
  const [stepIndex, setStepIndex] = useState(0);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [answers, setAnswers] = useState<Answers>(() => ({
    focus: student.goals.filter((g) => g.is_focus).map((g) => g.subject_id),
    targets: Object.fromEntries(
      student.goals
        .filter((g) => g.target_percent !== null)
        .map((g) => [g.subject_id, String(g.target_percent)]),
    ),
    sessionLength: student.studyProfile?.session_length ?? null,
    methods: student.studyProfile?.study_methods ?? [],
    times: student.studyProfile?.study_times ?? [],
  }));

  const step: Step = STEPS[stepIndex] ?? 'welcome';
  const subjectsById = useMemo(
    () => new Map(student.subjects.map((s) => [s.id, s])),
    [student.subjects],
  );
  // Focus subjects first, so the student sets those targets first.
  const targetOrder = useMemo(
    () => [
      ...answers.focus.map((id) => subjectsById.get(id)).filter((s) => s !== undefined),
      ...student.subjects.filter((s) => !answers.focus.includes(s.id)),
    ],
    [answers.focus, student.subjects, subjectsById],
  );

  const canContinue =
    step === 'welcome' ||
    (step === 'focus' && answers.focus.length > 0) ||
    (step === 'targets' && student.subjects.every((s) => validTarget(answers.targets[s.id]))) ||
    step === 'length' ||
    step === 'methods' ||
    step === 'times';

  async function save(finished: boolean) {
    const supabase = createClient();
    const base = {
      school_id: student.schoolId,
      academic_year_id: student.academicYearId,
      student_profile_id: student.profileId,
    };

    // Study habits.
    const { error: profileError } = await supabase.from('student_study_profiles').upsert(
      {
        ...base,
        session_length: answers.sessionLength,
        study_methods: answers.methods,
        study_times: answers.times,
        onboarding_completed_at: finished ? new Date().toISOString() : null,
      },
      { onConflict: 'school_id,academic_year_id,student_profile_id' },
    );
    if (profileError) throw profileError;

    // Goals. Clear focus first, so swapping focus subjects never briefly exceeds 3.
    const { error: clearError } = await supabase
      .from('student_subject_goals')
      .update({ is_focus: false })
      .eq('student_profile_id', student.profileId)
      .eq('academic_year_id', student.academicYearId);
    if (clearError) throw clearError;

    const rows = student.subjects.map((subject) => ({
      ...base,
      subject_id: subject.id,
      is_focus: answers.focus.includes(subject.id),
      target_percent: validTarget(answers.targets[subject.id])
        ? Number(answers.targets[subject.id])
        : null,
    }));
    const { error: goalsError } = await supabase
      .from('student_subject_goals')
      .upsert(rows, { onConflict: 'school_id,academic_year_id,student_profile_id,subject_id' });
    if (goalsError) throw goalsError;
  }

  async function next() {
    setError(null);
    const isLast = stepIndex === STEPS.length - 1;
    // Save after every question, so closing the app keeps progress.
    if (step !== 'welcome') {
      setSaving(true);
      try {
        await save(isLast);
      } catch (e) {
        // Supabase errors are plain objects with a message, not Error instances.
        const message =
          e && typeof e === 'object' && 'message' in e && typeof e.message === 'string'
            ? e.message
            : null;
        setError(`Couldn’t save your answers. ${message ?? 'Please try again.'}`);
        setSaving(false);
        return;
      }
      setSaving(false);
    }
    if (isLast) {
      router.push('/home');
      router.refresh();
    } else {
      setStepIndex(stepIndex + 1);
    }
  }

  const progress = stepIndex === 0 ? 0 : stepIndex / (STEPS.length - 1);

  return (
    <main className={styles.page}>
      <div className={styles.card}>
        <div className={styles.top}>
          <p className={styles.brand}>chom learn</p>
          {stepIndex > 0 && <p className={styles.count}>Question {stepIndex} of 5</p>}
        </div>
        <div
          className={styles.progress}
          role="progressbar"
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={Math.round(progress * 100)}
        >
          <span style={{ width: `${progress * 100}%` }} />
        </div>

        {step === 'welcome' && (
          <section className={styles.section}>
            <h1 className={styles.title}>Hi {student.name} 👋</h1>
            <p className={styles.muted}>
              {student.grade !== null ? `Grade ${student.grade}` : 'Student'}
              {student.classNames.length > 0 && ` · ${student.classNames.join(', ')}`} ·{' '}
              {student.schoolName}
            </p>
            <p>These are your subjects for {student.yearLabel}:</p>
            <ul className={styles.subjectList}>
              {student.subjects.map((s) => (
                <li key={s.id}>{s.name}</li>
              ))}
            </ul>
            <p className={styles.muted}>
              Five quick questions so Chom can help you study the right way. Something wrong with
              your subjects? Speak to your teacher.
            </p>
          </section>
        )}

        {step === 'focus' && (
          <section className={styles.section}>
            <h1 className={styles.title}>Which subjects do you want to improve the most?</h1>
            <p className={styles.muted}>Pick up to {MAX_FOCUS_SUBJECTS}.</p>
            <div className={styles.chips}>
              {student.subjects.map((s) => {
                const selected = answers.focus.includes(s.id);
                const full = answers.focus.length >= MAX_FOCUS_SUBJECTS;
                return (
                  <button
                    key={s.id}
                    type="button"
                    className={styles.chip}
                    aria-pressed={selected}
                    disabled={!selected && full}
                    onClick={() => setAnswers({ ...answers, focus: toggle(answers.focus, s.id) })}
                  >
                    {s.name}
                  </button>
                );
              })}
            </div>
          </section>
        )}

        {step === 'targets' && (
          <section className={styles.section}>
            <h1 className={styles.title}>What’s your goal for each subject?</h1>
            <p className={styles.muted}>The mark you’re aiming for. 80% or more is an A.</p>
            <div className={styles.targets}>
              {targetOrder.map((s) => (
                <label key={s.id} className={styles.targetRow}>
                  <span>
                    {s.name}
                    {answers.focus.includes(s.id) && <em className={styles.focusTag}>Focus</em>}
                  </span>
                  <span className={styles.targetInput}>
                    <input
                      type="number"
                      inputMode="numeric"
                      min={1}
                      max={100}
                      placeholder="—"
                      value={answers.targets[s.id] ?? ''}
                      aria-invalid={
                        answers.targets[s.id] !== undefined &&
                        answers.targets[s.id] !== '' &&
                        !validTarget(answers.targets[s.id])
                      }
                      onChange={(event) =>
                        setAnswers({
                          ...answers,
                          targets: { ...answers.targets, [s.id]: event.target.value },
                        })
                      }
                    />
                    %
                  </span>
                </label>
              ))}
            </div>
          </section>
        )}

        {step === 'length' && (
          <section className={styles.section}>
            <h1 className={styles.title}>How long do you usually study in one go?</h1>
            <div className={styles.chips}>
              {SESSION_LENGTHS.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  className={styles.chip}
                  aria-pressed={answers.sessionLength === option.value}
                  onClick={() => setAnswers({ ...answers, sessionLength: option.value })}
                >
                  {option.label}
                </button>
              ))}
            </div>
          </section>
        )}

        {step === 'methods' && (
          <section className={styles.section}>
            <h1 className={styles.title}>How do you usually study?</h1>
            <p className={styles.muted}>Pick as many as you like.</p>
            <div className={styles.chips}>
              {STUDY_METHODS.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  className={styles.chip}
                  aria-pressed={answers.methods.includes(option.value)}
                  onClick={() =>
                    setAnswers({ ...answers, methods: toggle(answers.methods, option.value) })
                  }
                >
                  {option.label}
                </button>
              ))}
            </div>
          </section>
        )}

        {step === 'times' && (
          <section className={styles.section}>
            <h1 className={styles.title}>When do you usually study?</h1>
            <p className={styles.muted}>Pick as many as you like.</p>
            <div className={styles.chips}>
              {STUDY_TIMES.map((option) => (
                <button
                  key={option.value}
                  type="button"
                  className={styles.chip}
                  aria-pressed={answers.times.includes(option.value)}
                  onClick={() =>
                    setAnswers({ ...answers, times: toggle(answers.times, option.value) })
                  }
                >
                  {option.label}
                </button>
              ))}
            </div>
          </section>
        )}

        {error && (
          <p className={styles.error} role="alert">
            {error}
          </p>
        )}

        <div className={styles.actions}>
          {stepIndex > 0 ? (
            <button
              type="button"
              className={styles.back}
              onClick={() => setStepIndex(stepIndex - 1)}
              disabled={saving}
            >
              Back
            </button>
          ) : (
            <span />
          )}
          <button
            type="button"
            className={styles.primary}
            onClick={next}
            disabled={!canContinue || saving}
          >
            {saving
              ? 'Saving…'
              : step === 'welcome'
                ? 'Let’s go'
                : stepIndex === STEPS.length - 1
                  ? 'Finish'
                  : 'Next'}
          </button>
        </div>
      </div>
    </main>
  );
}

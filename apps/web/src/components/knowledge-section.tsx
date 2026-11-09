'use client';

import Image from 'next/image';
import { useEffect, useRef, useState, type CSSProperties, type FormEvent } from 'react';

import styles from './knowledge-section.module.css';

const symbols = [
  { name: 'Mathematics', x: 11, y: 12, rotation: -14 },
  { name: 'Physical Sciences', x: 34, y: 8, rotation: 10 },
  { name: 'Arithmetic', x: 58, y: 17, rotation: -8 },
  { name: 'Life Sciences', x: 79, y: 8, rotation: 14 },
  { name: 'Geography', x: 91, y: 31, rotation: 9 },
  { name: 'Languages', x: 13, y: 36, rotation: -12 },
  { name: 'Economics', x: 72, y: 34, rotation: -7 },
  { name: 'Business Studies', x: 90, y: 54, rotation: 13 },
  { name: 'History', x: 9, y: 60, rotation: -10 },
  { name: 'Technology', x: 36, y: 30, rotation: 8 },
  { name: 'Visual Arts', x: 15, y: 83, rotation: -7 },
  { name: 'Music', x: 88, y: 80, rotation: 12 },
];

const clamp = (value: number) => Math.min(1, Math.max(0, value));

export function KnowledgeSection({ subjects }: { subjects: readonly string[] }) {
  const sectionRef = useRef<HTMLElement>(null);
  const sceneRef = useRef<HTMLDivElement>(null);
  const symbolRefs = useRef<(HTMLSpanElement | null)[]>([]);
  const questionRef = useRef<HTMLTextAreaElement>(null);
  const requestRef = useRef<AbortController | null>(null);
  const [subject, setSubject] = useState('');
  const [question, setQuestion] = useState('');
  const [pending, setPending] = useState(false);
  const [answer, setAnswer] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    const section = sectionRef.current;
    const scene = sceneRef.current;
    if (!section || !scene) return;

    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    let frame = 0;
    const update = () => {
      frame = 0;
      const bounds = section.getBoundingClientRect();
      const sceneBounds = scene.getBoundingClientRect();
      const sticky = window.innerWidth > 800 && window.innerHeight >= 850 && !answer;
      const progress = reducedMotion.matches
        ? 0
        : sticky
          ? clamp((24 - bounds.top) / Math.max(1, bounds.height - window.innerHeight))
          : clamp((window.innerHeight * 0.68 - sceneBounds.top) / (sceneBounds.height * 0.9));

      symbols.forEach((symbol, index) => {
        const element = symbolRefs.current[index];
        if (!element) return;
        const step = clamp((progress - (index % 4) * 0.09) / 0.7);
        const eased = step * step * (3 - 2 * step);
        const x = ((50 - symbol.x) / 100) * sceneBounds.width * eased;
        const y = ((45 - symbol.y) / 100) * sceneBounds.height * eased;
        element.style.transform = `translate(-50%, -50%) translate(${x}px, ${y}px) rotate(${symbol.rotation * (1 - eased)}deg) scale(${1 - eased * 0.88})`;
        element.style.opacity = String(1 - clamp((step - 0.62) / 0.38));
      });
    };
    const schedule = () => {
      if (!frame) frame = window.requestAnimationFrame(update);
    };
    schedule();
    window.addEventListener('scroll', schedule, { passive: true });
    window.addEventListener('resize', schedule);
    reducedMotion.addEventListener('change', schedule);
    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener('scroll', schedule);
      window.removeEventListener('resize', schedule);
      reducedMotion.removeEventListener('change', schedule);
    };
  }, [answer]);

  useEffect(() => () => requestRef.current?.abort(), []);

  function chooseSuggestion(nextSubject: string, nextQuestion: string) {
    setSubject(nextSubject);
    setQuestion(nextQuestion);
    setError('');
    questionRef.current?.focus();
  }

  async function askChom(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    const controller = new AbortController();
    requestRef.current = controller;
    setPending(true);
    setError('');
    setAnswer('');
    try {
      const response = await fetch('/api/ask-chom', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject, question }),
        signal: controller.signal,
      });
      const result = await response.json();
      if (!response.ok || typeof result.answer !== 'string') {
        throw new Error(result.error || 'Chom couldn’t answer just now. Please try again.');
      }
      setAnswer(result.answer);
    } catch (failure) {
      if (controller.signal.aborted) return;
      setError(
        failure instanceof Error ? failure.message : 'Please check your connection and try again.',
      );
    } finally {
      if (!controller.signal.aborted) setPending(false);
    }
  }

  return (
    <section
      id="ask-chom"
      ref={sectionRef}
      className={styles.section}
      aria-labelledby="knowledge-title"
      data-answer={answer ? 'true' : undefined}
    >
      <div className={styles.sticky}>
        <header className={styles.heading}>
          <h2 id="knowledge-title">Your subjects. All in here.</h2>
          <p>Meet Chom. Your curious little study companion.</p>
        </header>

        <div className={styles.layout}>
          <div className={styles.illustration}>
            <div className={styles.scene} ref={sceneRef} aria-hidden="true">
              <Image
                src="/images/chom-knowledge.webp"
                alt=""
                width={1254}
                height={1254}
                sizes="(max-width: 800px) 80vw, 480px"
                className={styles.mascot}
                unoptimized
              />
              {symbols.map((symbol, index) => (
                <span
                  key={symbol.name}
                  ref={(element) => {
                    symbolRefs.current[index] = element;
                  }}
                  className={styles.symbol}
                  style={
                    {
                      left: `${symbol.x}%`,
                      top: `${symbol.y}%`,
                      transform: `translate(-50%, -50%) rotate(${symbol.rotation}deg)`,
                      backgroundPosition: `${((index % 4) / 3) * 100}% ${Math.floor(index / 4) * 50}%`,
                    } as CSSProperties
                  }
                />
              ))}
            </div>
            <p className={styles.caption}>
              A little curiosity goes a long way. <span aria-hidden="true">↓</span>
            </p>
          </div>

          <form className={styles.form} onSubmit={askChom} aria-labelledby="ask-title">
            <h3 id="ask-title">Ask me a question.</h3>
            <p className={styles.formIntro}>Let’s work through it, together.</p>
            <label htmlFor="chom-subject">Subject</label>
            <select
              id="chom-subject"
              name="subject"
              value={subject}
              onChange={(event) => setSubject(event.target.value)}
              required
              disabled={pending}
            >
              <option value="" disabled>
                Choose a subject
              </option>
              {subjects.map((name) => (
                <option key={name}>{name}</option>
              ))}
            </select>

            <label htmlFor="chom-question">Your question</label>
            <textarea
              ref={questionRef}
              id="chom-question"
              name="question"
              placeholder="What would you like to understand?"
              rows={4}
              minLength={5}
              maxLength={1000}
              value={question}
              onChange={(event) => setQuestion(event.target.value)}
              required
              disabled={pending}
            />

            <button className={styles.submit} type="submit" disabled={pending}>
              {pending ? 'Chom is thinking…' : 'Ask Chom'}
              <span aria-hidden="true">{pending ? '···' : '→'}</span>
            </button>

            <div className={styles.suggestions}>
              <p>Need an idea?</p>
              <div>
                <button
                  type="button"
                  disabled={pending}
                  onClick={() =>
                    chooseSuggestion(
                      'Life Sciences',
                      'Can you explain photosynthesis in simple terms?',
                    )
                  }
                >
                  Explain photosynthesis
                </button>
                <button
                  type="button"
                  disabled={pending}
                  onClick={() =>
                    chooseSuggestion('Mathematics', 'How do I solve 2x + 5 = 17, step by step?')
                  }
                >
                  Help with algebra
                </button>
              </div>
            </div>
            <div aria-live="polite" aria-atomic="true" aria-busy={pending}>
              {error && (
                <p className={styles.message} role="alert">
                  {error}
                </p>
              )}
              {answer && (
                <div className={styles.answer}>
                  <h4>Chom says</h4>
                  <p>{answer}</p>
                  <small>Chom can make mistakes. Check important details with your teacher.</small>
                </div>
              )}
            </div>
          </form>
        </div>
      </div>
    </section>
  );
}

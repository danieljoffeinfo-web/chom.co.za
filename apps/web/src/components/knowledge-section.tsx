'use client';

import Image from 'next/image';
import { useEffect, useRef, type CSSProperties } from 'react';

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

// Centre of Chom’s tummy, expressed as a percentage of the illustration scene.
const absorptionPoint = { x: 50, y: 72 };

const clamp = (value: number) => Math.min(1, Math.max(0, value));

export function KnowledgeSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const sceneRef = useRef<HTMLDivElement>(null);
  const symbolRefs = useRef<(HTMLSpanElement | null)[]>([]);
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
      const sticky = window.innerWidth > 800 && window.innerHeight >= 850;
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
        const x = ((absorptionPoint.x - symbol.x) / 100) * sceneBounds.width * eased;
        const y = ((absorptionPoint.y - symbol.y) / 100) * sceneBounds.height * eased;
        element.style.transform = `translate(-50%, -50%) translate(${x}px, ${y}px) rotate(${symbol.rotation * (1 - eased)}deg) scale(${1 - eased * 0.88})`;
        element.style.opacity = String(1 - clamp((step - 0.84) / 0.16));
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
  }, []);

  return (
    <section
      id="ask-chom"
      ref={sectionRef}
      className={styles.section}
      aria-labelledby="knowledge-title"
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

          <p className={styles.copy}>
            Chom brings your subjects, tasks and timetable into one place. Open a subject to explore
            its topics and learning material, keep track of the work you need to finish, and see
            which lessons are coming up. Everything stays organised, so you can focus on learning.
          </p>
        </div>
      </div>
    </section>
  );
}

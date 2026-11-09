import Image from 'next/image';

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

export function KnowledgeSection() {
  return (
    <section id="ask-chom" className={styles.section} aria-labelledby="knowledge-title">
      <header className={styles.heading}>
        <h2 id="knowledge-title">Your subjects. All in here.</h2>
        <p>Meet Chom. Your curious little study companion.</p>
      </header>

      <div className={styles.layout}>
        <div className={styles.illustration}>
          <div className={styles.scene} aria-hidden="true">
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
                className={styles.symbol}
                style={{
                  left: `${symbol.x}%`,
                  top: `${symbol.y}%`,
                  transform: `translate(-50%, -50%) rotate(${symbol.rotation}deg)`,
                  backgroundPosition: `${((index % 4) / 3) * 100}% ${Math.floor(index / 4) * 50}%`,
                }}
              />
            ))}
          </div>
          <p className={styles.caption}>
            A little curiosity goes a long way. <span aria-hidden="true">↓</span>
          </p>
        </div>

        <div className={styles.copy}>
          <p className={styles.problem}>
            Most learners use AI the hard way: uploading documents, explaining the topic from
            scratch and hunting for resources every time they need help. AI is a great tool, but it
            doesn’t know your subjects, your syllabus or what your teacher set this week.
          </p>
          <p className={styles.answer}>
            <strong>Chom does.</strong> It already has your subject material and the files your
            teachers share, so every answer starts from where you are.
          </p>
        </div>
      </div>
    </section>
  );
}

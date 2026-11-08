'use client';

import { useState } from 'react';
import styles from './page.module.css';

const views = ['Subjects', 'Tasks', 'Timetable'] as const;
type View = (typeof views)[number];
const tasks = ['Finish algebra practice', 'Read chapter three', 'Prepare biology notes'];

export function HomePreview() {
  const [view, setView] = useState<View>('Subjects');
  const [completed, setCompleted] = useState<number[]>([1]);
  return (
    <div className={styles.previewStage}>
      <div className={styles.previewLabel}><span aria-hidden="true">↙</span> A little look inside Chom</div>
      <div className={styles.preview}>
        <div className={styles.windowBar}><span className={styles.windowDots} aria-hidden="true"><i /><i /><i /></span><span>Your workspace</span><span className={styles.sample}>Sample</span></div>
        <div className={styles.previewBody}>
          <div className={styles.previewGreeting}><div><p>LET’S MAKE TODAY COUNT</p><h2>Hey, you.</h2></div><span className={styles.avatar} aria-hidden="true">Y</span></div>
          <div className={styles.previewTabs} role="group" aria-label="Choose a workspace preview">
            {views.map((item) => <button key={item} type="button" aria-pressed={view === item} onClick={() => setView(item)}>{item}</button>)}
          </div>
          <div className={styles.previewContent} aria-live="polite">
            {view === 'Subjects' && <div>
              <div className={styles.previewHeading}><h3>Your subjects</h3><span>3 subjects</span></div>
              <div className={styles.subjects}>
                {[['M', 'Mathematics', 'Patterns. Problems. Possibilities.'], ['L', 'Life Sciences', 'A closer look at the living world.'], ['E', 'English', 'Find the words. Find your voice.']].map(([letter, title, description]) => <div className={styles.subject} key={title}><span className={styles.subjectIcon}>{letter}</span><div><h4>{title}</h4><p>{description}</p></div><span className={styles.subjectArrow} aria-hidden="true">↗</span></div>)}
              </div>
              <div className={styles.goal}><span aria-hidden="true">◎</span><p>A little progress, every day.<small>Your goals start with your next step.</small></p></div>
            </div>}
            {view === 'Tasks' && <div>
              <div className={styles.previewHeading}><h3>A few things for today</h3><span>{completed.length} / 3 done</span></div>
              <div className={styles.taskList}>{tasks.map((task, i) => <label className={styles.taskItem} key={task}><input type="checkbox" checked={completed.includes(i)} onChange={() => setCompleted((current) => current.includes(i) ? current.filter((n) => n !== i) : [...current, i])} /><span>{task}<small>{['Mathematics', 'English', 'Life Sciences'][i]}</small></span></label>)}</div>
              <p className={styles.previewHint}>{completed.length === 3 ? 'All done. A little breathing room, earned.' : 'Try ticking something off. Small wins count.'}</p>
            </div>}
            {view === 'Timetable' && <div>
              <div className={styles.previewHeading}><h3>Your morning, at a glance</h3><span>Monday</span></div>
              <ol className={styles.schedule}>{[['08:00', 'Mathematics', 'Start with a fresh perspective'], ['09:00', 'Life Sciences', 'Time to get curious'], ['10:00', 'Break', 'Take a moment for yourself'], ['10:30', 'English', 'A new chapter']].map(([time, title, note]) => <li key={time}><time>{time}</time><div><strong>{title}</strong><small>{note}</small></div></li>)}</ol>
            </div>}
          </div>
          <div className={styles.previewBottom}><span className={styles.statusDot} aria-hidden="true" /> Your day, a little more together.<span aria-hidden="true">↗</span></div>
        </div>
      </div>
      <div className={styles.floatingNote}><span className={styles.noteIcon} aria-hidden="true">✓</span><div>One less thing to remember.<small>A little more space to think.</small></div></div>
      <p className={styles.previewCaption}>Interactive preview · Example subjects and tasks</p>
    </div>
  );
}

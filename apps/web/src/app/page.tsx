import Image from 'next/image';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { Logo } from '@/components/logo';
import { KnowledgeSection } from '@/components/knowledge-section';
import { STUDY_SUBJECTS } from '@/lib/ask-chom';
import styles from './page.module.css';

export default async function Landing() {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  if (data?.claims) redirect('/start');

  return (
    <div className={styles.landing}>
      <a className={styles.skip} href="#main">
        Skip to content
      </a>
      <header className={styles.header}>
        <Link href="/" aria-label="Chom home">
          <Logo height={30} />
        </Link>
        <nav aria-label="Main navigation">
          <a className={styles.navLink} href="#ask-chom">
            Explore Chom
          </a>
          <Link className={styles.navLink} href="/sign-in?as=staff">
            For teachers
          </Link>
          <Link className={styles.navCta} href="/sign-in">
            Sign in <span aria-hidden="true">↗</span>
          </Link>
        </nav>
      </header>
      <main id="main">
        <section className={styles.hero} aria-labelledby="hero-title">
          <div className={styles.heroCopy}>
            <h1 id="hero-title">
              Everything at
              <br />
              your fingertips.
            </h1>
            <p className={styles.lede}>
              Your subjects, tasks and timetable, together. Make room for learning with a clearer
              view of what’s next.
            </p>
            <div className={styles.actions}>
              <Link className={styles.cta} href="/sign-in">
                Let’s get started <span aria-hidden="true">↗</span>
              </Link>
              <a className={styles.textLink} href="#ask-chom">
                Take a look around <span aria-hidden="true">↓</span>
              </a>
            </div>
            <div className={styles.heroNote}>
              <span aria-hidden="true">↳</span> Less looking for things. More getting into them.
            </div>
          </div>
          <div className={styles.heroVisual} aria-hidden="true">
            <Image
              src="/images/chom-study-desk.webp"
              alt=""
              width={1536}
              height={1024}
              className={styles.heroArtwork}
              preload
              unoptimized
            />
          </div>
        </section>
        <KnowledgeSection subjects={STUDY_SUBJECTS} />

        <section id="your-day" className={styles.features} aria-labelledby="features-title">
          <div className={styles.sectionHead}>
            <div>
              <p className={styles.eyebrow}>A clearer school day</p>
              <h2 id="features-title">Everything has its place.</h2>
            </div>
            <p>
              From the first lesson to the last thing on your list. Keep the everyday essentials
              close.
            </p>
          </div>
          <div className={styles.featureGrid}>
            <article className={styles.feature}>
              <div className={styles.subjectVisual} aria-hidden="true">
                <span>
                  Mathematics <b>↗</b>
                </span>
                <span>
                  Life Sciences <b>↗</b>
                </span>
                <span>
                  English <b>↗</b>
                </span>
              </div>
              <p className={styles.featureNumber}>01 / Your subjects</p>
              <h3>A home for every subject.</h3>
              <p>All your key topics and content, organised in one place.</p>
            </article>
            <article className={styles.feature}>
              <div className={styles.taskVisual} aria-hidden="true">
                <span>
                  <i>✓</i> Finish the first draft
                </span>
                <span>
                  <i /> Revise for tomorrow
                </span>
                <span>
                  <i /> Hand in your assignment
                </span>
              </div>
              <p className={styles.featureNumber}>02 / Your tasks</p>
              <h3>Know what needs doing.</h3>
              <p>Stay on top of your schoolwork and leave time for what truly matters.</p>
            </article>
            <article className={styles.feature}>
              <div className={styles.timeVisual} aria-hidden="true">
                <div>
                  <span>08:00</span>
                  <b>
                    Mathematics<small>First lesson</small>
                  </b>
                </div>
                <div>
                  <span>09:00</span>
                  <b>
                    Life Sciences<small>Up next</small>
                  </b>
                </div>
              </div>
              <p className={styles.featureNumber}>03 / Your timetable</p>
              <h3>Find your rhythm.</h3>
              <p>
                See how your day fits together, so the next lesson feels a little less like a
                surprise.
              </p>
            </article>
          </div>
        </section>
      </main>
      <footer className={styles.footer}>
        <Logo height={24} />
        <p>Study the right way with Chom.</p>
        <Link href="/sign-in">
          Make yourself at home <span aria-hidden="true">↗</span>
        </Link>
      </footer>
    </div>
  );
}

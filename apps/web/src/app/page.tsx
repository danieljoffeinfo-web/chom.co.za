import Image from 'next/image';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';
import { Logo } from '@/components/logo';
import { KnowledgeSection } from '@/components/knowledge-section';
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
        <KnowledgeSection />

        <section id="powered-by" className={styles.poweredBy} aria-labelledby="powered-title">
          <h2 id="powered-title">Powered by</h2>
          <div className={styles.providerLogos}>
            <div className={styles.openaiLogo}>
              <Image
                src="/images/providers/openai.webp"
                alt=""
                width={1254}
                height={1254}
                className={styles.openaiMark}
                unoptimized
              />
              <span>OpenAI</span>
            </div>
            <div className={styles.claudeLogo}>
              <Image
                src="/images/providers/claude-mark.svg"
                alt=""
                width={48}
                height={48}
                className={styles.claudeMark}
                unoptimized
              />
              <Image
                src="/images/providers/claude-wordmark.svg"
                alt="Claude"
                width={166}
                height={41}
                className={styles.claudeWordmark}
                unoptimized
              />
            </div>
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

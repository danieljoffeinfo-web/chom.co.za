import { Icon, type IconName } from './icon';

/** A page that's in the navigation but not built yet: what it will do, in one place. */
export function ComingSoon({
  title,
  intro,
  icon,
  points,
}: {
  title: string;
  intro: string;
  icon: IconName;
  points: string[];
}) {
  return (
    <>
      <header className="view-header">
        <div>
          <h1>{title}</h1>
          <p>{intro}</p>
        </div>
      </header>
      <section className="panel">
        <div className="empty-message">
          <Icon name={icon} />
          <h2>Coming soon</h2>
          <ul className="coming-list">
            {points.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
        </div>
      </section>
    </>
  );
}

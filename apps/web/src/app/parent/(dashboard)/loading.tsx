/** Shown the moment a section is tapped, while its data loads. */
export default function Loading() {
  return (
    <>
      <p className="visually-hidden" role="status">
        Loading…
      </p>
      <div className="cd" aria-hidden="true">
        <div className="skeleton-block skeleton-title" />
        <div className="skeleton-block skeleton-line" />
        <div className="skeleton-cards">
          <div className="skeleton-block skeleton-card" />
          <div className="skeleton-block skeleton-card" />
          <div className="skeleton-block skeleton-card" />
        </div>
      </div>
    </>
  );
}

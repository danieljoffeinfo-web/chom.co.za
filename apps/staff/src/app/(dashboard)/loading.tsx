/**
 * Shown the moment a tab is clicked, while the page's data loads. The sidebar stays
 * put, so switching tabs never looks frozen.
 */
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

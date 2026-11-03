/**
 * Shown the moment a tab is clicked, while the page's data loads. The sidebar stays
 * put, so switching tabs never looks frozen.
 */
export default function Loading() {
  return (
    <div className="cd" aria-busy="true" aria-label="Loading">
      <div className="skeleton-block skeleton-title" />
      <div className="skeleton-block skeleton-line" />
      <div className="skeleton-cards">
        <div className="skeleton-block skeleton-card" />
        <div className="skeleton-block skeleton-card" />
        <div className="skeleton-block skeleton-card" />
      </div>
    </div>
  );
}

'use client';

/** If a page's content fails to load, inside the dashboard frame. */
export default function ParentError({ retry }: { error: Error; retry: () => void }) {
  return (
    <section className="panel">
      <div className="empty-message">
        <h2>We couldn’t load this page</h2>
        <p>Please try again in a moment.</p>
        {/* retry asks the server again; reset alone would redraw the same failure. */}
        <button className="button secondary" type="button" onClick={retry}>
          Try again
        </button>
      </div>
    </section>
  );
}

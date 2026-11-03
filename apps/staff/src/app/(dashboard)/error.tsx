'use client';

/** If loading a page fails (for example the database is briefly unreachable). */
export default function DashboardError({ reset }: { error: Error; reset: () => void }) {
  return (
    <section className="panel">
      <div className="empty-message">
        <h2>We couldn’t load this page</h2>
        <p>Please try again in a moment.</p>
        <button className="button secondary" type="button" onClick={reset}>
          Try again
        </button>
      </div>
    </section>
  );
}

export function Methodology() {
  return (
    <section id="methodology">
      <div className="container">
        <div style={{ maxWidth: '900px', margin: '0 auto', width: '100%' }}>
        <h2 style={{ marginBottom: 'var(--space-xl)', textAlign: 'center' }}>Methodology & Source Code</h2>
        
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: 'var(--space-xl)' }}>
          
          {/* Query Index */}
          <div>
            <h3 style={{ marginBottom: 'var(--space-md)' }}>SQL Query Index</h3>
            <ul style={{ listStyleType: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 'var(--space-sm)' }}>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>01_monthly_revenue.sql</strong><br/>
                Aggregates total delivered orders and item-price revenue by month.
              </li>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>02_delay_vs_review.sql</strong><br/>
                Calculates the lift in bad review rates by grouping orders into on-time vs. late delivery.
              </li>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>03_review_by_category_state.sql</strong><br/>
                Segments performance across product categories and Brazilian states to expose variance.
              </li>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>04_seller_ranking.sql</strong><br/>
                Identifies and ranks the best and worst individual sellers based on their specific bad review rates.
              </li>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>04b_category_seller_counts.sql</strong><br/>
                Provides qualifying seller counts per category to establish statistical significance for rankings.
              </li>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>05_repeat_purchase.sql</strong><br/>
                Calculates global customer retention and repeat purchase rates.
              </li>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>06_cohort_retention.sql</strong><br/>
                Tracks time-based retention by organizing customers into monthly cohorts based on first purchase.
              </li>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>07_late_delivery_attribution.sql</strong><br/>
                Generates delay thresholds to map exactly how each day of delay degrades average review scores.
              </li>
              <li style={{ fontSize: 'var(--text-sm)' }}>
                <strong style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-accent)' }}>08_excess_bad_reviews.sql</strong><br/>
                Calculates the theoretical upper bound of bad reviews mathematically attributable to lateness.
              </li>
            </ul>
          </div>

          {/* Caveats */}
          <div>
            <h3 style={{ marginBottom: 'var(--space-md)' }}>Key Data Caveats</h3>
            <ul style={{ paddingLeft: 'var(--space-md)', margin: 0, display: 'flex', flexDirection: 'column', gap: 'var(--space-sm)' }}>
              <li style={{ color: 'var(--color-text-muted)' }}>
                <strong style={{ color: 'var(--color-text)' }}>Delivered Orders Only:</strong> This analysis strictly scopes to orders with a `delivered` status. Canceled or permanently lost orders are excluded entirely.
              </li>
              <li style={{ color: 'var(--color-text-muted)' }}>
                <strong style={{ color: 'var(--color-text)' }}>Review Deduplication:</strong> For orders possessing multiple reviews, only the most recent review score is counted to prevent duplicate weighing.
              </li>
              <li style={{ color: 'var(--color-text-muted)' }}>
                <strong style={{ color: 'var(--color-text)' }}>Item-Price Revenue:</strong> All revenue metrics track item price exclusively and do not include freight/shipping costs.
              </li>
              <li style={{ color: 'var(--color-text-muted)' }}>
                <strong style={{ color: 'var(--color-text)' }}>Observational, Not Causal:</strong> The findings are correlational. Category difficulty (e.g., heavy furniture), region remoteness, and intrinsic seller quality are highly entangled with lateness and were not completely isolated.
              </li>
            </ul>

            <div style={{ marginTop: 'var(--space-xl)', padding: 'var(--space-md)', backgroundColor: 'rgba(255,255,255,0.02)', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.1)' }}>
              <h4 style={{ marginBottom: 'var(--space-sm)' }}>Reproduce the Analysis</h4>
              <p style={{ fontSize: 'var(--text-sm)', color: 'var(--color-text-muted)', marginBottom: 'var(--space-md)' }}>
                The raw queries, duckdb build scripts, and this frontend application are entirely open source.
              </p>
              <a href="https://github.com/24jainnikita/olist-post-mortem" target="_blank" rel="noopener noreferrer" style={{ display: 'inline-block', backgroundColor: 'var(--color-text)', color: 'var(--color-bg)', padding: '8px 16px', borderRadius: '4px', textDecoration: 'none', fontWeight: 'bold', fontSize: 'var(--text-sm)' }}>
                View Source on GitHub
              </a>
            </div>
          </div>

        </div>
        </div>
      </div>
    </section>
  );
}

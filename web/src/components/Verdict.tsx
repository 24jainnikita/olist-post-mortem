import summaryData from '../data/summary.json';

export function Verdict() {
  return (
    <section id="verdict">
      <div className="container">
        <div style={{ maxWidth: '900px', margin: '0 auto', width: '100%' }}>
          <h2 style={{ marginBottom: 'var(--space-xl)', textAlign: 'center' }}>The Verdict</h2>
        
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-lg)' }}>
          {/* Recommendation 1 */}
          <div style={{ backgroundColor: 'var(--color-surface)', padding: 'var(--space-lg)', borderRadius: '8px', borderLeft: '4px solid var(--color-accent)' }}>
            <h3 style={{ marginBottom: 'var(--space-sm)' }}>1. Institute a hard intervention at 7 Days Late</h3>
            <p style={{ color: 'var(--color-text-muted)', marginBottom: 'var(--space-sm)', lineHeight: 1.5 }}>
              The data proves that lateness is catastrophic, but extreme lateness guarantees a negative outcome. For orders that are 7 or more days late, the bad review rate skyrockets to a massive <strong className="accent data-number">{summaryData.seven_plus_days_late_bad_review_rate.toFixed(1)}%</strong>. 
            </p>
            <p style={{ fontSize: 'var(--text-sm)', color: 'rgba(255,255,255,0.4)', fontFamily: 'var(--font-mono)' }}>
              Source: 07_late_delivery_attribution.sql / summary.json
            </p>
          </div>

          {/* Recommendation 2 */}
          <div style={{ backgroundColor: 'var(--color-surface)', padding: 'var(--space-lg)', borderRadius: '8px', borderLeft: '4px solid var(--color-accent)' }}>
            <h3 style={{ marginBottom: 'var(--space-sm)' }}>2. Attack lateness to reclaim a quarter of all bad reviews</h3>
            <p style={{ color: 'var(--color-text-muted)', marginBottom: 'var(--space-sm)', lineHeight: 1.5 }}>
              By comparing late orders against the baseline on-time bad review rate (9.22%), we attribute an upper bound of <strong className="accent data-number">{summaryData.excess_bad_reviews.toLocaleString()}</strong> excess bad reviews directly to lateness. This represents <strong className="accent data-number">{summaryData.excess_as_pct_of_all_bad.toFixed(1)}%</strong> of all bad reviews system-wide. While category and seller quality are confounding variables (and thus this is strictly an upper bound), solving logistics could theoretically eradicate over a quarter of negative sentiment.
            </p>
            <p style={{ fontSize: 'var(--text-sm)', color: 'rgba(255,255,255,0.4)', fontFamily: 'var(--font-mono)' }}>
              Source: 08_excess_bad_reviews.sql / 08_excess_bad_reviews.json
            </p>
          </div>

          {/* Recommendation 3 */}
          <div style={{ backgroundColor: 'var(--color-surface)', padding: 'var(--space-lg)', borderRadius: '8px', borderLeft: '4px solid var(--color-accent)' }}>
            <h3 style={{ marginBottom: 'var(--space-sm)' }}>3. Audit bottom-ranked sellers in high-friction categories</h3>
            <p style={{ color: 'var(--color-text-muted)', marginBottom: 'var(--space-sm)', lineHeight: 1.5 }}>
              Lateness is not evenly distributed, and specific individual sellers correlate highly with poor outcomes. For example, a seller in the Computers Accessories category is associated with a <strong className="accent data-number">57.1%</strong> bad review rate across 57 orders. Given the difficulty of isolating seller quality from inherent category friction, we recommend systematically auditing (rather than immediately purging) sellers who rank in the bottom 10 of their respective high-volume categories to identify structural issues.
            </p>
            <p style={{ fontSize: 'var(--text-sm)', color: 'rgba(255,255,255,0.4)', fontFamily: 'var(--font-mono)' }}>
              Source: 04_seller_ranking.sql / 04_seller_ranking.json
            </p>
          </div>
        </div>
        </div>
      </div>
    </section>
  );
}

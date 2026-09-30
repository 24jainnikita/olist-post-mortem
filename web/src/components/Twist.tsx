import { useMemo } from 'react';
import categoryStateData from '../data/03_review_by_category_state.json';
import sellerRankingData from '../data/04_seller_ranking.json';
import categorySellerCounts from '../data/04b_category_seller_counts.json';

export function Twist() {
  const worstCategories = useMemo(() => {
    const cats = categoryStateData.filter((d: any) => d.dimension === 'category' && d.segment !== 'unknown');
    return cats.sort((a: any, b: any) => b.pct_low_review - a.pct_low_review).slice(0, 5);
  }, []);

  const worstSellers = useMemo(() => {
    const sellers = sellerRankingData.filter((s: any) => (s.tier === 'bottom_10' || s.tier === 'both') && !s.few_qualifying_sellers && s.category !== 'unknown');
    return sellers.sort((a: any, b: any) => b.pct_low_review - a.pct_low_review).slice(0, 5);
  }, []);

  const getSellerCount = (category: string) => {
    const match = categorySellerCounts.find((c: any) => c.category === category);
    return match ? match.qualifying_seller_count : 0;
  };

  return (
    <section id="twist">
      <div className="container">
        <h2 style={{ marginBottom: 'var(--space-md)', textAlign: 'center' }}>The Complication</h2>
        <p style={{ textAlign: 'center', color: 'var(--color-text-muted)', maxWidth: '800px', margin: '0 auto', marginBottom: 'var(--space-xl)', fontStyle: 'italic' }}>
          Category, region, and seller quality may all correlate with delivery lateness, making it difficult to isolate single causes for individual sellers.
        </p>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--space-xl)', width: '100%' }}>
          
          {/* Categories */}
          <div>
            <h3 style={{ marginBottom: 'var(--space-md)' }}>Worst-Performing Categories</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
              {worstCategories.map((c: any) => {
                const sellerCount = getSellerCount(c.segment);
                const isSmallSample = sellerCount < 20;
                
                // Visual weight relative to the highest in the list
                const maxPct = worstCategories[0]?.pct_low_review || 1;
                const weight = c.pct_low_review / maxPct;

                return (
                  <div key={c.segment} style={{ paddingBottom: 'var(--space-sm)', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: '4px' }}>
                      <strong style={{ fontSize: `calc(1rem + ${weight * 0.5}rem)`, textTransform: 'capitalize', opacity: 0.5 + (weight * 0.5) }}>
                        {c.segment.replace(/_/g, ' ')}
                      </strong>
                      <span className="data-number accent" style={{ fontSize: `calc(1rem + ${weight * 0.5}rem)` }}>{c.pct_low_review.toFixed(1)}%</span>
                    </div>
                    
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 'var(--text-sm)', color: 'var(--color-text-muted)' }}>
                      <span>{c.order_count.toLocaleString()} orders</span>
                      <span>Bad Reviews</span>
                    </div>

                    {isSmallSample && (
                      <div style={{ marginTop: '8px', fontSize: 'var(--text-xs)', color: 'var(--color-text-muted)' }}>
                        ⚠️ Small sample ({sellerCount} qualifying sellers)
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Sellers */}
          <div>
            <h3 style={{ marginBottom: 'var(--space-md)' }}>Bottom-Ranked Sellers</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
              {worstSellers.map((s: any) => {
                const maxPct = worstSellers[0]?.pct_low_review || 1;
                const weight = s.pct_low_review / maxPct;

                return (
                  <div key={`${s.seller_id}-${s.category}`} style={{ paddingBottom: 'var(--space-sm)', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: '4px' }}>
                      <span style={{ fontSize: `calc(1rem + ${weight * 0.5}rem)`, fontFamily: 'var(--font-mono)', opacity: 0.5 + (weight * 0.5) }}>
                        {s.seller_id.substring(0, 8)}...
                      </span>
                      <span className="data-number accent" style={{ fontSize: `calc(1rem + ${weight * 0.5}rem)` }}>{s.pct_low_review.toFixed(1)}%</span>
                    </div>
                    
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 'var(--text-sm)', color: 'var(--color-text-muted)' }}>
                      <span style={{ textTransform: 'capitalize' }}>{s.category.replace(/_/g, ' ')} ({s.order_count} orders)</span>
                      <span>Bad Reviews</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}

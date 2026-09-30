import React, { useState, Suspense } from 'react';
import thresholdData from '../data/threshold.json';

const BrazilHexMap = React.lazy(() => import('./BrazilHexMap').then(m => ({ default: m.BrazilHexMap })));

export function Evidence() {
  const [thresholdIndex, setThresholdIndex] = useState(7);
  const data = thresholdData[thresholdIndex];

  return (
    <section id="evidence">
      <div className="container">
        <h2 style={{ marginBottom: 'var(--space-xl)', textAlign: 'center' }}>The Evidence</h2>
        
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--space-xl)', width: '100%' }}>
          
          {/* Slider Part */}
          <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
            <h3 style={{ marginBottom: 'var(--space-sm)' }}>Delay Thresholds</h3>
            <p style={{ color: 'var(--color-text-muted)', marginBottom: 'var(--space-lg)' }}>
              Adjust the slider to see how delay tolerance affects customer sentiment.
            </p>

            <div style={{ marginBottom: 'var(--space-xl)' }}>
              <input 
                type="range" 
                min="0" 
                max="15" 
                value={thresholdIndex}
                onChange={(e) => setThresholdIndex(Number(e.target.value))}
                style={{ width: '100%', cursor: 'pointer', accentColor: 'var(--color-accent)' }}
                aria-label="Delay Threshold in Days"
              />
              <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--color-text-muted)', fontSize: 'var(--text-xs)', marginTop: 'var(--space-xs)', fontFamily: 'var(--font-mono)' }}>
                <span>0 days</span>
                <span>15 days</span>
              </div>
            </div>

            <div style={{ backgroundColor: 'var(--color-surface)', padding: 'var(--space-lg)', borderRadius: '8px' }}>
              <p style={{ fontSize: 'var(--text-lg)', marginBottom: 'var(--space-md)', lineHeight: 1.4 }}>
                At <strong className="accent data-number">{data.threshold_days}+</strong> days late, <strong className="accent data-number">{data.share_exceeding_pct.toFixed(1)}%</strong> of all delivered orders exceed this threshold.
              </p>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-md)', marginTop: 'var(--space-lg)', paddingTop: 'var(--space-md)', borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                <div>
                  <p style={{ fontSize: 'var(--text-xs)', color: 'var(--color-good)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>&le; {data.threshold_days} days late</p>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px', marginTop: '4px' }}>
                    <span className="data-number good" style={{ fontSize: 'var(--text-2xl)' }}>{data.avg_score_below.toFixed(2)}</span>
                    <span style={{ color: 'var(--color-good)' }}>★</span>
                  </div>
                </div>
                <div>
                  <p style={{ fontSize: 'var(--text-xs)', color: 'var(--color-accent)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>&gt; {data.threshold_days} days late</p>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px', marginTop: '4px' }}>
                    <span className="data-number accent" style={{ fontSize: 'var(--text-2xl)' }}>{data.avg_score_above.toFixed(2)}</span>
                    <span style={{ color: 'var(--color-accent)' }}>★</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Map Part */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
            <h3 style={{ marginBottom: 'var(--space-sm)' }}>Geographic Variance</h3>
            <p style={{ color: 'var(--color-text-muted)', marginBottom: 'var(--space-lg)', textAlign: 'center' }}>
              Bad review rates isolated by delivery state.
            </p>
            <Suspense fallback={<div style={{ height: 320, display: 'flex', alignItems: 'center', color: 'var(--color-text-muted)' }}>Loading map...</div>}>
              <BrazilHexMap />
            </Suspense>
          </div>

        </div>
      </div>
    </section>
  );
}

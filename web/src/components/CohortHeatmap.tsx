import { useMemo, useState } from 'react';
import cohortData from '../data/06_cohort_retention.json';
import summaryData from '../data/summary.json';

export function CohortHeatmap() {
  const [hoveredCell, setHoveredCell] = useState<any | null>(null);

  const cohorts = useMemo(() => {
    const rawMonths = Array.from(new Set(cohortData.map((d: any) => d.cohort_month)));
    return rawMonths.sort();
  }, []);

  const monthsSince = useMemo(() => {
    const rawMonths = Array.from(new Set(cohortData.filter((d: any) => d.months_since_first_purchase > 0).map((d: any) => d.months_since_first_purchase)));
    return rawMonths.sort((a, b) => (a as number) - (b as number));
  }, []);

  const dataMap = useMemo(() => {
    const map = new Map<string, any>();
    cohortData.forEach((d: any) => {
      map.set(`${d.cohort_month}-${d.months_since_first_purchase}`, d);
    });
    return map;
  }, []);

  const maxRetention = useMemo(() => {
    let max = 0;
    cohortData.forEach((d: any) => {
      if (d.months_since_first_purchase > 0 && d.retention_pct > max) {
        max = d.retention_pct;
      }
    });
    return max;
  }, []);

  const getColor = (pct: number | undefined) => {
    if (pct === undefined || pct === null) return 'transparent';
    if (pct === 0) return 'rgba(255,255,255,0.02)';
    const ratio = pct / maxRetention;
    return `rgba(242, 163, 58, ${0.1 + ratio * 0.9})`;
  };

  const formatMonth = (dateString: string) => {
    const d = new Date(dateString);
    return d.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
  };

  const CELL_SIZE = 36;
  const MARGIN_LEFT = 100;
  const MARGIN_TOP = 40;
  
  const width = MARGIN_LEFT + monthsSince.length * CELL_SIZE;
  const height = MARGIN_TOP + cohorts.length * CELL_SIZE;

  return (
    <section id="cohort-heatmap" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', alignItems: 'center' }}>
      <div className="container" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <h2 style={{ marginBottom: 'var(--space-sm)', textAlign: 'center' }}>Cohort Retention</h2>
        <p style={{ color: 'var(--color-text-muted)', marginBottom: 'var(--space-xl)', maxWidth: '800px', textAlign: 'center' }}>
          The overall repeat purchase rate is a critically low <strong className="accent data-number">{summaryData.repeat_purchase_rate.toFixed(1)}%</strong>. Even among established cohorts, almost no customers return after their first purchase.
        </p>

        <div style={{ overflowX: 'auto', maxWidth: '100vw', padding: '0 var(--space-md)' }}>
          <div style={{ position: 'relative', width, height }}>
            <svg width={width} height={height}>
              <g transform={`translate(${MARGIN_LEFT}, 0)`}>
                {monthsSince.map((m, i) => (
                  <text key={m as number} x={i * CELL_SIZE + CELL_SIZE / 2} y={MARGIN_TOP - 10} textAnchor="middle" fill="var(--color-text-muted)" fontSize="12px" fontFamily="var(--font-mono)">
                    {m as number}
                  </text>
                ))}
                <text x={monthsSince.length * CELL_SIZE / 2} y={15} textAnchor="middle" fill="rgba(255,255,255,0.5)" fontSize="11px" style={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  Months Since First Purchase
                </text>
              </g>

              <g transform={`translate(0, ${MARGIN_TOP})`}>
                {cohorts.map((cohort, rowIndex) => (
                  <g key={cohort as string} transform={`translate(0, ${rowIndex * CELL_SIZE})`}>
                    <text x={MARGIN_LEFT - 10} y={CELL_SIZE / 2} textAnchor="end" alignmentBaseline="middle" fill="rgba(255,255,255,0.8)" fontSize="12px">
                      {formatMonth(cohort as string)}
                    </text>
                    
                    {monthsSince.map((m, colIndex) => {
                      const d = dataMap.get(`${cohort}-${m}`);
                      const pct = d ? d.retention_pct : undefined;
                      const isHovered = hoveredCell === d;
                      
                      return (
                        <g 
                          key={m as number}
                          transform={`translate(${MARGIN_LEFT + colIndex * CELL_SIZE}, 0)`}
                          onMouseEnter={() => setHoveredCell(d)}
                          onMouseLeave={() => setHoveredCell(null)}
                          onFocus={() => setHoveredCell(d)}
                          onBlur={() => setHoveredCell(null)}
                          tabIndex={d ? 0 : -1}
                          style={{ outline: 'none', cursor: d ? 'pointer' : 'default' }}
                        >
                          <rect 
                            width={CELL_SIZE - 2} 
                            height={CELL_SIZE - 2} 
                            fill={getColor(pct)}
                            stroke={isHovered ? "#fff" : "transparent"}
                            strokeWidth={isHovered ? 2 : 0}
                            rx={2}
                            style={{ transition: 'all 0.1s' }}
                          />
                        </g>
                      );
                    })}
                  </g>
                ))}
              </g>
            </svg>

            {/* Tooltip */}
            {hoveredCell && (
              <div style={{
                position: 'absolute',
                top: '100%',
                left: '50%',
                transform: 'translateX(-50%)',
                marginTop: 'var(--space-lg)',
                backgroundColor: 'var(--color-surface)',
                border: '1px solid var(--color-accent)',
                padding: 'var(--space-sm) var(--space-md)',
                borderRadius: '4px',
                textAlign: 'center',
                pointerEvents: 'none',
                zIndex: 10
              }}>
                <strong>{formatMonth(hoveredCell.cohort_month)}</strong> cohort<br/>
                <span className="data-number accent">{hoveredCell.retention_pct.toFixed(2)}%</span> retention at month {hoveredCell.months_since_first_purchase}
                <div style={{ fontSize: '12px', color: 'var(--color-text-muted)', marginTop: '4px' }}>
                  ({hoveredCell.retained_users} of {hoveredCell.cohort_size} users)
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}

import { useState } from 'react';
import stateData from '../data/03_review_by_category_state.json';

const GRID = {
  RR: [2, 0], AP: [4, 0],
  AM: [1, 1], PA: [3, 1], MA: [5, 1], CE: [7, 1], RN: [9, 1],
  AC: [0, 2], RO: [2, 2], MT: [4, 2], TO: [6, 2], PI: [8, 2], PB: [10, 2],
  MS: [3, 3], GO: [5, 3], BA: [7, 3], PE: [9, 3], AL: [11, 3],
  DF: [6, 4], MG: [8, 4], SE: [10, 4],
  PR: [5, 5], SP: [7, 5], ES: [9, 5],
  SC: [6, 6], RJ: [8, 6],
  RS: [7, 7]
};

const HEX_SIZE = 24;
const HEX_WIDTH = Math.sqrt(3) * HEX_SIZE;
const HEX_HEIGHT = 2 * HEX_SIZE;

function getHexPoints(cx: number, cy: number) {
  const points = [];
  for (let i = 0; i < 6; i++) {
    const angle_deg = 60 * i - 30;
    const angle_rad = Math.PI / 180 * angle_deg;
    points.push(`${cx + HEX_SIZE * Math.cos(angle_rad)},${cy + HEX_SIZE * Math.sin(angle_rad)}`);
  }
  return points.join(" ");
}

export function BrazilHexMap() {
  const [hoveredState, setHoveredState] = useState<string | null>(null);

  const states = stateData.filter((d: any) => d.dimension === 'state');
  
  const pctValues = states.map((d: any) => d.pct_low_review || 0);
  const minPct = Math.min(...pctValues);
  const maxPct = Math.max(...pctValues);

  const getColor = (pct: number) => {
    const ratio = (pct - minPct) / (maxPct - minPct);
    return `rgba(242, 163, 58, ${0.15 + ratio * 0.85})`; 
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative' }}>
      <svg width="100%" height={320} viewBox="0 0 550 320" style={{ maxWidth: '550px' }}>
        {Object.entries(GRID).map(([abbr, [q, r]]) => {
          const data = states.find((s: any) => s.segment === abbr);
          if (!data) return null;

          const cx = q * HEX_WIDTH + (r % 2 === 1 ? HEX_WIDTH / 2 : 0) + 40;
          const cy = r * (HEX_HEIGHT * 0.75) + 30;
          const isHovered = hoveredState === abbr;
          const pct = data.pct_low_review || 0;

          return (
            <g 
              key={abbr}
              tabIndex={0}
              onMouseEnter={() => setHoveredState(abbr)}
              onMouseLeave={() => setHoveredState(null)}
              onFocus={() => setHoveredState(abbr)}
              onBlur={() => setHoveredState(null)}
              style={{ outline: 'none', cursor: 'pointer' }}
              aria-label={`${abbr}, ${pct.toFixed(1)}% bad reviews`}
            >
              <polygon 
                points={getHexPoints(cx, cy)}
                fill={getColor(pct)}
                stroke={isHovered ? "#fff" : "rgba(255,255,255,0.05)"}
                strokeWidth={isHovered ? 2 : 1}
                style={{ transition: 'all 0.2s' }}
              />
              <text 
                x={cx} 
                y={cy} 
                textAnchor="middle" 
                alignmentBaseline="middle"
                fill={isHovered ? "#fff" : "rgba(255,255,255,0.9)"}
                fontSize="12px"
                fontWeight="500"
                fontFamily="var(--font-mono)"
                pointerEvents="none"
              >
                {abbr}
              </text>
            </g>
          );
        })}
      </svg>
      
      <div style={{ marginTop: 'var(--space-md)', minHeight: '60px', textAlign: 'center', width: '100%' }}>
        {hoveredState ? (() => {
          const data = states.find((s: any) => s.segment === hoveredState);
          if (!data) return null;
          const pct = data.pct_low_review || 0;
          const count = data.order_count || 0;
          return (
            <div style={{ backgroundColor: 'var(--color-surface)', padding: 'var(--space-sm) var(--space-md)', borderRadius: '4px', display: 'inline-block', border: '1px solid rgba(242, 163, 58, 0.3)' }}>
              <strong>{hoveredState}</strong>: {count.toLocaleString()} orders &nbsp;|&nbsp; <span className="data-number accent">{pct.toFixed(1)}%</span> bad reviews
            </div>
          );
        })() : (
          <div style={{ color: 'var(--color-text-muted)' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', marginBottom: '8px' }}>
              <span className="data-number" style={{ fontSize: '12px' }}>{minPct.toFixed(1)}%</span>
              <div style={{ width: '120px', height: '6px', borderRadius: '3px', background: `linear-gradient(to right, rgba(242, 163, 58, 0.15), rgba(242, 163, 58, 1))` }} />
              <span className="data-number" style={{ fontSize: '12px' }}>{maxPct.toFixed(1)}%</span>
            </div>
            <p style={{ fontSize: '12px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Bad Review Rate</p>
          </div>
        )}
      </div>
    </div>
  );
}

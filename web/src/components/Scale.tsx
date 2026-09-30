import { useState, useEffect } from "react";
import { animate } from "framer-motion";
import { useInView } from "../hooks/useInView";
import { useReducedMotion } from "../hooks/useReducedMotion";
import summaryData from "../data/summary.json";

function Counter({ from, to, format, duration = 2, className = "data-number accent" }: { from: number, to: number, format: (val: number) => string, duration?: number, className?: string }) {
  const [value, setValue] = useState(from);
  const { ref, isInView } = useInView({ once: true, margin: "-100px" });
  const reduceMotion = useReducedMotion();

  useEffect(() => {
    if (isInView) {
      if (reduceMotion) {
        setValue(to);
      } else {
        const controls = animate(from, to, {
          duration,
          onUpdate: (latest) => setValue(latest),
          ease: "easeOut"
        });
        return controls.stop;
      }
    }
  }, [from, to, isInView, reduceMotion, duration]);

  return <span ref={ref as any} className={className}>{format(value)}</span>;
}

export function Scale() {
  return (
    <section id="scale">
      <div className="container">
        <div style={{ maxWidth: "800px" }}>
          <h2 style={{ marginBottom: "var(--space-lg)" }}>The Scale of the Problem</h2>
          
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-md)" }}>
            <div>
              <div style={{ fontSize: "var(--text-3xl)", lineHeight: 1.1 }}>
                <Counter 
                  from={0} 
                  to={summaryData.total_delivered_orders} 
                  format={v => Math.round(v).toLocaleString()} 
                  className="data-number good"
                />
              </div>
              <p style={{ color: "var(--color-text-muted)", fontSize: "var(--text-sm)" }}>Total delivered orders</p>
            </div>

            <div>
              <div style={{ fontSize: "var(--text-3xl)", lineHeight: 1.1 }}>
                <Counter 
                  from={0} 
                  to={summaryData.total_revenue} 
                  format={v => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 }).format(Math.round(v))} 
                  className="data-number good"
                />
              </div>
              <p style={{ color: "var(--color-text-muted)", fontSize: "var(--text-sm)" }}>Revenue (Item price only, excluding freight)</p>
            </div>

            <div>
              <div style={{ fontSize: "var(--text-3xl)", lineHeight: 1.1 }}>
                <Counter 
                  from={0} 
                  to={summaryData.repeat_purchase_rate} 
                  format={v => v.toFixed(1) + "%"} 
                  className="data-number accent"
                />
              </div>
              <p style={{ color: "var(--color-text-muted)", fontSize: "var(--text-sm)" }}>Repeat purchase rate</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

import { useRef, useState } from "react";
import { motion, useScroll, useMotionValueEvent } from "framer-motion";
import { useReducedMotion } from "../hooks/useReducedMotion";
import thresholdData from "../data/threshold.json";
import summaryData from "../data/summary.json";

export function Suspect() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"]
  });
  
  const reduceMotion = useReducedMotion();
  const [activeIndex, setActiveIndex] = useState(reduceMotion ? 15 : 0);

  useMotionValueEvent(scrollYProgress, "change", (latest) => {
    if (reduceMotion) return;
    const index = Math.min(15, Math.max(0, Math.floor(latest * 16)));
    setActiveIndex(index);
  });

  const currentData = thresholdData[activeIndex];
  const maxDelay = 15;
  const progressPercent = reduceMotion ? 100 : (activeIndex / maxDelay) * 100;

  return (
    <section id="suspect" ref={containerRef} style={{ height: reduceMotion ? "100vh" : "400vh", position: "relative", padding: 0 }}>
        <div style={{ 
          position: reduceMotion ? "relative" : "sticky", 
          top: 0, 
          height: "100vh", 
          display: "flex", 
          flexDirection: "column", 
          justifyContent: "center", 
          padding: "var(--space-xl) var(--space-md)",
          maxWidth: "1400px",
          margin: "0 auto",
          width: "100%"
        }}>
          <h2 style={{ marginBottom: "var(--space-lg)" }}>The Prime Suspect: Delivery Delays</h2>
          <p style={{ color: "var(--color-text-muted)", fontSize: "var(--text-lg)", marginBottom: "var(--space-xl)", maxWidth: "600px" }}>
            As the delay increases, customer satisfaction collapses. Watch the review score drop as the parcel journey is extended.
          </p>
          
          {/* The Timeline */}
          <div style={{ position: "relative", margin: "var(--space-xl) 0" }}>
            {/* Base line */}
            <div style={{ height: "2px", backgroundColor: "rgba(255,255,255,0.1)", width: "100%", position: "absolute", top: "50%", transform: "translateY(-50%)" }}></div>
            
            {/* Fill line */}
            <motion.div 
              style={{ 
                height: "2px", 
                backgroundColor: "var(--color-accent)", 
                width: `${progressPercent}%`,
                position: "absolute", 
                top: "50%", 
                transform: "translateY(-50%)",
                transition: "width 0.1s linear"
              }}
            />

            {/* Tick marks for every day */}
            {[...Array(16)].map((_, i) => (
              <div key={i} style={{
                position: "absolute",
                top: "50%",
                left: `${(i / 15) * 100}%`,
                transform: "translate(-50%, -50%)",
                width: "4px",
                height: "4px",
                borderRadius: "50%",
                backgroundColor: i <= activeIndex ? "var(--color-accent)" : "rgba(255,255,255,0.2)",
                transition: "background-color 0.1s linear"
              }} />
            ))}

            {/* Marker */}
            <motion.div
              style={{
                position: "absolute",
                top: "50%",
                left: `${progressPercent}%`,
                transform: "translate(-50%, -50%)",
                color: "var(--color-bg)",
                backgroundColor: "var(--color-accent)",
                padding: "8px",
                borderRadius: "50%",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                transition: "left 0.1s linear",
                zIndex: 10,
                boxShadow: "0 0 10px var(--color-accent)"
              }}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="16.5" y1="9.4" x2="7.5" y2="4.21"></line>
                <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
                <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
                <line x1="12" y1="22.08" x2="12" y2="12"></line>
              </svg>
            </motion.div>

            {/* Callout at 7 days */}
            <div style={{
              position: "absolute",
              left: `${(7 / 15) * 100}%`,
              top: "32px",
              transform: "translateX(-50%)",
              textAlign: "center",
              width: "200px"
            }}>
              <div style={{ height: "24px", borderLeft: "1px dashed rgba(255,255,255,0.3)", margin: "0 auto", marginBottom: "8px" }}></div>
              <p className="data-number accent" style={{ fontSize: "var(--text-xl)", lineHeight: 1 }}>
                {summaryData.seven_plus_days_late_bad_review_rate.toFixed(1)}%
              </p>
              <p style={{ fontSize: "var(--text-xs)", color: "var(--color-text-muted)" }}>
                Bad reviews if 7+ days late
              </p>
            </div>
          </div>

          {/* Stats */}
          <div style={{ display: "grid", gridTemplateColumns: "1fr auto", gap: "var(--space-lg)", marginTop: "120px", alignItems: "end" }}>
            <div>
              <p style={{ fontSize: "var(--text-sm)", color: "var(--color-text-muted)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "var(--space-xs)" }}>Current Delay</p>
              <div style={{ display: "flex", alignItems: "baseline", gap: "var(--space-xs)" }}>
                <p className="data-number accent" style={{ fontSize: "var(--text-hero)", lineHeight: 1 }}>{currentData.threshold_days}</p>
                <p style={{ fontSize: "var(--text-lg)", color: "var(--color-text-muted)" }}>Days late</p>
              </div>
            </div>
            
            <div style={{ display: "flex", gap: "var(--space-xl)" }}>
              <div>
                <p style={{ fontSize: "var(--text-sm)", color: "var(--color-good)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "var(--space-xs)" }}>&le; {currentData.threshold_days} days late</p>
                <div style={{ display: "flex", alignItems: "baseline", gap: "var(--space-sm)" }}>
                  <p className="data-number good" style={{ fontSize: "var(--text-3xl)", lineHeight: 1 }}>{currentData.avg_score_below.toFixed(2)}</p>
                  <span style={{ fontSize: "var(--text-xl)", color: "var(--color-good)" }}>★</span>
                </div>
              </div>

              <div>
                <p style={{ fontSize: "var(--text-sm)", color: "var(--color-accent)", textTransform: "uppercase", letterSpacing: "0.05em", marginBottom: "var(--space-xs)" }}>&gt; {currentData.threshold_days} days late</p>
                <div style={{ display: "flex", alignItems: "baseline", gap: "var(--space-sm)" }}>
                  <p className="data-number accent" style={{ fontSize: "var(--text-3xl)", lineHeight: 1 }}>{currentData.avg_score_above.toFixed(2)}</p>
                  <span style={{ fontSize: "var(--text-xl)", color: "var(--color-accent)" }}>★</span>
                </div>
              </div>
            </div>
          </div>
        </div>
    </section>
  );
}

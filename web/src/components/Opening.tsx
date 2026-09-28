import { motion } from "framer-motion";
import { useReducedMotion } from "../hooks/useReducedMotion";

export function Opening() {
  const reduceMotion = useReducedMotion();

  const animation = reduceMotion ? {} : {
    initial: { opacity: 0, y: 20 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 1.5, ease: "easeOut" as const }
  };

  return (
    <section id="opening" style={{ alignItems: "center", textAlign: "center", justifyContent: "center", position: "relative" }}>
      <motion.div {...animation} style={{ maxWidth: "800px" }}>
        <h1 style={{ marginBottom: "var(--space-sm)" }}>
          "Deram um prazo muito grande para a entrega do produto e não conseguiram entregar no prazo."
        </h1>
        <p style={{ fontStyle: "italic", color: "var(--color-text-muted)", fontSize: "var(--text-lg)", marginBottom: "var(--space-md)" }}>
          "They gave a very long deadline for product delivery and were unable to deliver on time."
        </p>
        <p className="data-number accent" style={{ fontSize: "var(--text-xs)", opacity: 0.8, textTransform: "uppercase", letterSpacing: "0.05em" }}>
          Actual 1-star review • Order ID: f58c538485f196aedcc7a7f6cbe34dd6
        </p>
      </motion.div>
      <motion.div 
        style={{ position: "absolute", bottom: "var(--space-lg)" }}
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: reduceMotion ? 0 : 2, duration: 1 }}
      >
        <p className="data-number" style={{ fontSize: "var(--text-xs)", color: "var(--color-text-muted)", letterSpacing: "0.1em", textTransform: "uppercase" }}>
          Scroll to explore &darr;
        </p>
      </motion.div>
    </section>
  );
}

import { useReducedMotion as useFramerReducedMotion } from "framer-motion";

/**
 * Returns a boolean indicating if the user has requested reduced motion.
 */
export function useReducedMotion(): boolean {
  const shouldReduceMotion = useFramerReducedMotion();
  return shouldReduceMotion === true;
}

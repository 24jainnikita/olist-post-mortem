import { useInView as useFramerInView } from "framer-motion";
import type { UseInViewOptions } from "framer-motion";
import { useRef } from "react";
import { useReducedMotion } from "./useReducedMotion";

/**
 * Wrapper around framer-motion's useInView that automatically 
 * returns true if prefers-reduced-motion is enabled, bypassing the scroll reveal.
 */
export function useInView(options: UseInViewOptions = {}) {
  const ref = useRef<Element>(null);
  const isInView = useFramerInView(ref, options);
  const shouldReduceMotion = useReducedMotion();

  return {
    ref,
    isInView: shouldReduceMotion ? true : isInView,
  };
}

"use client";

import type { ReactNode } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X } from "@/lib/lucide-react";

export function Dialog({
  kicker,
  title,
  children,
  onClose,
}: {
  kicker: string;
  title: string;
  children: ReactNode;
  onClose: () => void;
}) {
  return (
    <AnimatePresence>
      <motion.div
        className="dialog-backdrop"
        role="presentation"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        transition={{ duration: 0.18 }}
      >
        <motion.section
          className="dialog ops-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby="record-dialog-title"
          initial={{ opacity: 0, scale: 0.95, y: 12 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 12 }}
          transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
        >
          <button
            className="icon-button"
            style={{ float: "right" }}
            onClick={onClose}
            aria-label="Close"
          >
            <X size={16} />
          </button>
          <p className="dialog-kicker">{kicker}</p>
          <h3 id="record-dialog-title">{title}</h3>
          {children}
        </motion.section>
      </motion.div>
    </AnimatePresence>
  );
}

"use client";

import { useEffect, useId, useRef, type ReactNode } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { confirmFormClose } from "./PortalStateProvider";
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
  const dialogRef = useRef<HTMLElement>(null);
  const closeRef = useRef(onClose);
  closeRef.current = () => { if (confirmFormClose(dialogRef.current)) onClose(); };
  const titleId = useId();

  useEffect(() => {
    const previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const focusable = () => Array.from(dialogRef.current?.querySelectorAll<HTMLElement>(
      'input:not([type="hidden"]):not(:disabled), select:not(:disabled), textarea:not(:disabled), button:not(:disabled), a[href], [tabindex="0"]',
    ) ?? []).filter((element) => element.getClientRects().length > 0);
    const initial = dialogRef.current?.querySelector<HTMLElement>('input:not([type="hidden"]):not(:disabled), select:not(:disabled), textarea:not(:disabled)');
    (initial ?? focusable()[0] ?? dialogRef.current)?.focus();
    const onKeyDown = (event: KeyboardEvent) => {
      const dialogs = document.querySelectorAll('[role="dialog"]');
      if (dialogs[dialogs.length - 1] !== dialogRef.current) return;
      if (event.key === "Escape") {
        event.preventDefault();
        if (!dialogRef.current?.querySelector('form[aria-busy="true"]')) closeRef.current();
      }
      if (event.key === "Tab") {
        const elements = focusable();
        const first = elements[0];
        const last = elements[elements.length - 1];
        if (!first) { event.preventDefault(); dialogRef.current?.focus(); }
        else if (event.shiftKey && (document.activeElement === first || !dialogRef.current?.contains(document.activeElement))) {
          event.preventDefault(); last.focus();
        } else if (!event.shiftKey && (document.activeElement === last || !dialogRef.current?.contains(document.activeElement))) {
          event.preventDefault(); first.focus();
        }
      }
    };
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.body.style.overflow = previousOverflow;
      previousFocus?.focus();
    };
  }, []);

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
          ref={dialogRef}
          tabIndex={-1}
          className="dialog ops-dialog"
          role="dialog"
          aria-modal="true"
          aria-labelledby={titleId}
          initial={{ opacity: 0, scale: 0.95, y: 12 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 12 }}
          transition={{ duration: 0.22, ease: [0.16, 1, 0.3, 1] }}
        >
          <button
            className="icon-button"
            style={{ float: "right" }}
            onClick={() => closeRef.current()}
            aria-label="Close"
          >
            <X size={16} />
          </button>
          <p className="dialog-kicker">{kicker}</p>
          <h3 id={titleId}>{title}</h3>
          {children}
        </motion.section>
      </motion.div>
    </AnimatePresence>
  );
}

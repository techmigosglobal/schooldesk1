"use client";

import { useEffect, useState } from "react";
import { CheckCircle2, CircleAlert, Info, X } from "lucide-react";

export interface ToastItem {
  id: string;
  message: string;
  type?: "success" | "error" | "info";
}

export function ToastContainer({
  toasts,
  onDismiss,
}: {
  toasts: ToastItem[];
  onDismiss: (id: string) => void;
}) {
  if (!toasts.length) return null;

  return (
    <div className="ops-toast-stack" role="status" aria-live="polite">
      {toasts.map((toast) => (
        <ToastSingle key={toast.id} toast={toast} onDismiss={onDismiss} />
      ))}
    </div>
  );
}

function ToastSingle({
  toast,
  onDismiss,
}: {
  toast: ToastItem;
  onDismiss: (id: string) => void;
}) {
  const [exiting, setExiting] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => {
      setExiting(true);
      setTimeout(() => onDismiss(toast.id), 250);
    }, 4500);
    return () => clearTimeout(timer);
  }, [toast.id, onDismiss]);

  const handleManualDismiss = () => {
    setExiting(true);
    setTimeout(() => onDismiss(toast.id), 250);
  };

  const Icon =
    toast.type === "error"
      ? CircleAlert
      : toast.type === "info"
        ? Info
        : CheckCircle2;

  return (
    <div className={`ops-toast ${toast.type || "success"} ${exiting ? "exiting" : ""}`}>
      <Icon size={18} />
      <span>{toast.message}</span>
      <button onClick={handleManualDismiss} aria-label="Dismiss notification">
        <X size={15} />
      </button>
    </div>
  );
}

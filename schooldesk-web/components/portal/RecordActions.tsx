"use client";

import { useEffect, useId, useRef, useState } from "react";
import { createPortal } from "react-dom";

type RecordAction = { label: string; onSelect: () => void; danger?: boolean; disabled?: boolean };

/** Secondary record commands; visible View/Edit buttons remain beside the trigger. */
export function RecordActions({ label, actions }: { label: string; actions: RecordAction[] }) {
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState({ top: 0, left: 0 });
  const trigger = useRef<HTMLButtonElement>(null);
  const menu = useRef<HTMLDivElement>(null);
  const id = useId();
  function close(restoreFocus = false) {
    setOpen(false);
    if (restoreFocus) trigger.current?.focus();
  }
  useEffect(() => {
    if (!open) return;
    menu.current?.querySelector<HTMLButtonElement>("button:not(:disabled)")?.focus();
    function outside(event: PointerEvent) {
      if (!menu.current?.contains(event.target as Node) && !trigger.current?.contains(event.target as Node)) close();
    }
    function move() { close(); }
    document.addEventListener("pointerdown", outside);
    window.addEventListener("resize", move);
    window.addEventListener("scroll", move, true);
    return () => {
      document.removeEventListener("pointerdown", outside);
      window.removeEventListener("resize", move);
      window.removeEventListener("scroll", move, true);
    };
  }, [open]);
  return <>
    <button ref={trigger} type="button" className="secondary-button record-actions-trigger" aria-label={label} aria-haspopup="menu" aria-expanded={open} aria-controls={open ? id : undefined} onClick={() => {
      const rect = trigger.current?.getBoundingClientRect();
      if (rect) setPosition({ top: Math.max(8, Math.min(rect.bottom + 5, window.innerHeight - actions.length * 44 - 20)), left: Math.max(8, Math.min(rect.right - 224, window.innerWidth - 232)) });
      setOpen(!open);
    }} onKeyDown={(event) => {
      if (event.key === "ArrowDown" || event.key === "ArrowUp") { event.preventDefault(); trigger.current?.click(); }
    }}>More<span aria-hidden="true"> ⋯</span></button>
    {open && createPortal(<div ref={menu} id={id} role="menu" aria-label={label} className="record-actions-menu" style={position} onBlur={(event) => {
      if (!event.currentTarget.contains(event.relatedTarget as Node)) close();
    }} onKeyDown={(event) => {
      if (event.key === "Escape") { event.preventDefault(); event.stopPropagation(); close(true); }
      const buttons = Array.from(menu.current?.querySelectorAll<HTMLButtonElement>("button:not(:disabled)") ?? []);
      const index = buttons.indexOf(document.activeElement as HTMLButtonElement);
      if (["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) {
        event.preventDefault();
        const next = event.key === "Home" ? 0 : event.key === "End" ? buttons.length - 1 : (index + (event.key === "ArrowDown" ? 1 : -1) + buttons.length) % buttons.length;
        buttons[next]?.focus();
      }
    }}>{actions.map((action) => <button key={action.label} type="button" role="menuitem" className={action.danger ? "danger" : ""} disabled={action.disabled} onClick={() => { close(true); action.onSelect(); }}>{action.label}</button>)}</div>, document.body)}
  </>;
}

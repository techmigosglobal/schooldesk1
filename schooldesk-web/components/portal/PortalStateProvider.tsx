"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type Dispatch, type ReactNode, type SetStateAction } from "react";
import { restorePortalValue } from "@/lib/portal-view-storage";
import type { PortalRole } from "@/lib/roles";
import { parsePortalTarget, serializePortalTarget, type PortalTarget } from "@/lib/portal-navigation";

type Guard = { dirty: boolean; saving: boolean };
type Refresh = (manual?: boolean) => void | Promise<void>;
type PortalContext = {
  scope: string; role: PortalRole; target: PortalTarget; ready: boolean;
  navigate: (target: PortalTarget, replace?: boolean) => boolean;
  confirmLeave: () => boolean;
  registerGuard: (id: symbol, value: Guard | null) => void;
  registerRefresh: (id: symbol, callback: Refresh | null) => void;
  refresh: () => Promise<void>; refreshing: boolean; canRefresh: boolean; refreshedAt: string; refreshError: string;
};
const Context = createContext<PortalContext | null>(null);
const PREFIX = "schooldesk:portal:v1:";
export function clearPortalViewStorage() {
  try { for (const key of Object.keys(sessionStorage)) if (key.startsWith(PREFIX)) sessionStorage.removeItem(key); } catch { /* Browser storage can be unavailable. */ }
}
export function clearSavedFormMarkers() {
  document.querySelectorAll('form[data-portal-dirty]').forEach(form => form.removeAttribute('data-portal-dirty'));
}
export function confirmFormClose(element: HTMLElement | null): boolean {
  if (element?.querySelector('form[aria-busy="true"],button[aria-busy="true"]')) return false;
  if (!element?.querySelector('form[data-portal-dirty="true"]')) return true;
  if (!window.confirm("Discard the unsaved changes in this form?")) return false;
  element.querySelectorAll('form[data-portal-dirty]').forEach(form => form.removeAttribute('data-portal-dirty'));
  return true;
}
function usePortalContext() {
  const context = useContext(Context);
  if (!context) throw new Error("Portal view state requires a portal scope.");
  return context;
}
export function PortalStateProvider({ scope, role, children }: { scope: string; role: PortalRole; children: ReactNode }) {
  const [target, setTarget] = useState<PortalTarget>({ module: "overview" });
  const [ready, setReady] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [canRefresh, setCanRefresh] = useState(false);
  const [refreshedAt, setRefreshedAt] = useState("");
  const [refreshError, setRefreshError] = useState("");
  const guards = useRef(new Map<symbol, Guard>());
  const callbacks = useRef(new Map<symbol, Refresh>());
  const historyIndex = useRef(0);
  const lastUrl = useRef("");
  const restoring = useRef(false);
  const refreshLock = useRef(false);
  const viewKey = `${PREFIX}${scope}:navigation`;

  const confirmLeave = useCallback(() => {
    const current = [...guards.current.values()];
    if (current.some(guard => guard.saving) || document.querySelector('form[aria-busy="true"],[role="dialog"] button[aria-busy="true"]')) return false;
    const formsDirty = Boolean(document.querySelector('form[data-portal-dirty="true"]'));
    if (!formsDirty && !current.some(guard => guard.dirty)) return true;
    if (!window.confirm("Discard unsaved changes before leaving this view?")) return false;
    clearSavedFormMarkers();
    return true;
  }, []);
  const registerGuard = useCallback((id: symbol, guard: Guard | null) => {
    if (guard) guards.current.set(id, guard); else guards.current.delete(id);
  }, []);
  const registerRefresh = useCallback((id: symbol, callback: Refresh | null) => {
    if (callback) callbacks.current.set(id, callback); else callbacks.current.delete(id);
    setCanRefresh(callbacks.current.size > 0);
  }, []);
  const remember = useCallback((next: PortalTarget) => {
    setTarget(next);
    try { sessionStorage.setItem(viewKey, JSON.stringify(next)); sessionStorage.setItem(`${viewKey}:${next.module}`, JSON.stringify(next)); } catch { /* In-memory navigation remains available. */ }
  }, [viewKey]);
  const navigate = useCallback((next: PortalTarget, replace = false) => {
    if (!replace && !next.tab && !next.sectionId) {
      try { const saved = JSON.parse(sessionStorage.getItem(`${viewKey}:${next.module}`) ?? "null"); if (saved?.module === next.module) next = { ...saved, ...next }; } catch { /* Ignore invalid saved destinations. */ }
    }
    const query = serializePortalTarget(next, role);
    if (!confirmLeave()) return false;
    if (`${location.pathname}${query}` === lastUrl.current) return true;
    const index = replace ? historyIndex.current : historyIndex.current + 1;
    const url = `${location.pathname}${query}`;
    window.history[replace ? "replaceState" : "pushState"]({ ...history.state, portalIndex: index }, "", url);
    historyIndex.current = index;
    lastUrl.current = url;
    remember(parsePortalTarget(query, role));
    window.scrollTo({ top: 0 });
    return true;
  }, [confirmLeave, remember, role, viewKey]);

  useEffect(() => {
    let initial = parsePortalTarget(location.search, role);
    if (!new URLSearchParams(location.search).has("module")) {
      try { const saved = JSON.parse(sessionStorage.getItem(viewKey) ?? "null"); if (saved?.module) initial = parsePortalTarget(serializePortalTarget(saved, role), role); } catch { /* Ignore corrupt view state. */ }
    }
    const url = `${location.pathname}${serializePortalTarget(initial, role)}`;
    historyIndex.current = typeof history.state?.portalIndex === "number" ? history.state.portalIndex : 0;
    history.replaceState({ ...history.state, portalIndex: historyIndex.current }, "", url);
    lastUrl.current = url;
    remember(initial);
    setReady(true);
    const pop = (event: PopStateEvent) => {
      const index = typeof event.state?.portalIndex === "number" ? event.state.portalIndex : 0;
      if (restoring.current) { restoring.current = false; return; }
      if (!confirmLeave()) {
        const delta = historyIndex.current - index;
        if (delta) { restoring.current = true; history.go(delta); }
        else history.replaceState({ ...history.state, portalIndex: historyIndex.current }, "", lastUrl.current);
        return;
      }
      historyIndex.current = index;
      const next = parsePortalTarget(location.search, role);
      lastUrl.current = `${location.pathname}${serializePortalTarget(next, role)}`;
      // Canonicalise unsupported/foreign role tabs without triggering a new navigation.
      history.replaceState({ ...history.state, portalIndex: index }, "", lastUrl.current);
      remember(next);
    };
    const markDirty = (event: Event) => {
      const element = event.target;
      if (!(element instanceof HTMLElement)) return;
      const form = element.closest("form");
      if (form && form.dataset.portalTransient !== "true" && (form.closest(".ops-portal") || form.closest('[role="dialog"]'))) form.dataset.portalDirty = "true";
    };
    const beforeUnload = (event: BeforeUnloadEvent) => {
      if ([...guards.current.values()].some(g => g.dirty || g.saving) || document.querySelector('form[data-portal-dirty="true"],form[aria-busy="true"],[role="dialog"] button[aria-busy="true"]')) {
        event.preventDefault(); event.returnValue = "";
      }
    };
    window.addEventListener("popstate", pop);
    window.addEventListener("beforeunload", beforeUnload);
    document.addEventListener("input", markDirty);
    document.addEventListener("change", markDirty);
    return () => {
      window.removeEventListener("popstate", pop); window.removeEventListener("beforeunload", beforeUnload);
      document.removeEventListener("input", markDirty); document.removeEventListener("change", markDirty);
    };
  }, [confirmLeave, remember, role, viewKey]);

  const refresh = useCallback(async () => {
    if (refreshLock.current || !confirmLeave()) return;
    const callback = [...callbacks.current.values()].at(-1);
    if (!callback) return;
    refreshLock.current = true;
    setRefreshing(true); setRefreshError("");
    try { await callback(true); setRefreshedAt(new Date().toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })); }
    catch (error) { setRefreshError(error instanceof Error ? error.message : "Unable to refresh this view."); }
    finally { refreshLock.current = false; setRefreshing(false); }
  }, [confirmLeave]);
  const value = useMemo(() => ({ scope, role, target, ready, navigate, confirmLeave, registerGuard, registerRefresh, refresh, refreshing, canRefresh, refreshedAt, refreshError }), [scope, role, target, ready, navigate, confirmLeave, registerGuard, registerRefresh, refresh, refreshing, canRefresh, refreshedAt, refreshError]);
  return <Context.Provider value={value}>{children}</Context.Provider>;
}

export function usePortalNavigation() { return usePortalContext(); }
export function usePortalState<T>(key: string, initial: T | (() => T)): [T, Dispatch<SetStateAction<T>>] {
  const { scope } = usePortalContext();
  const storageKey = `${PREFIX}${scope}:${key}`;
  const [value, setValue] = useState<T>(() => {
    const fallback = typeof initial === "function" ? (initial as () => T)() : initial;
    try {
      return restorePortalValue(sessionStorage.getItem(storageKey), fallback);
    } catch { /* Unavailable/corrupt storage falls back safely. */ }
    return fallback;
  });
  const set = useCallback<Dispatch<SetStateAction<T>>>((action) => {
    setValue(previous => {
      const next = typeof action === "function" ? (action as (previous: T) => T)(previous) : action;
      try { const json = JSON.stringify(next); if (json.length < 4096) sessionStorage.setItem(storageKey, json); } catch { /* View state can remain memory-only. */ }
      return next;
    });
  }, [storageKey]);
  // Provider is keyed by scope; a changed account/branch never reuses this hook instance.
  return [value, set];
}
export function usePortalTab<T extends string>(module: string, initial: T): [T, (next: T) => void] {
  const { target, navigate } = usePortalContext();
  return [(target.module === module && target.tab ? target.tab : initial) as T, useCallback((next: T) => { navigate({ ...target, module, tab: next }); }, [target, navigate, module])];
}
export function usePortalGuard(dirty: boolean, saving = false) {
  const { registerGuard } = usePortalContext();
  const id = useRef(Symbol("portal-guard"));
  useEffect(() => { registerGuard(id.current, { dirty, saving }); return () => registerGuard(id.current, null); }, [dirty, saving, registerGuard]);
}

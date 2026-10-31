"use client";
import { useEffect, useRef } from "react";
import { usePortalNavigation } from "./PortalStateProvider";

export function usePortalRefresh(load: (manual?: boolean) => void | Promise<void>, enabled = true) {
  const { registerRefresh } = usePortalNavigation();
  const id = useRef(Symbol("view-refresh"));
  const callback = useRef(load);
  callback.current = load;
  useEffect(() => {
    const key = id.current;
    if (enabled) registerRefresh(key, manual => callback.current(manual));
    return () => registerRefresh(key, null);
  }, [enabled, registerRefresh]);
}

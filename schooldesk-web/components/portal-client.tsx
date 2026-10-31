"use client";

import { useCallback, useEffect, useState } from "react";
import Image from "next/image";
import type { PortalRole } from "@/lib/roles";
import { visibleModules } from "@/lib/roles";
import { modules, navMeta, type Row } from "@/components/portal/types";
import type { ToastItem } from "@/components/portal/Toast";
import { ToastContainer } from "@/components/portal/Toast";
import { PortalPageHeader } from "@/components/portal/PortalPageHeader";
import { DashboardPanel } from "@/components/portal/DashboardPanel";
import { ResourceModule } from "@/components/portal/ResourceModule";
import { FeesWorkspace } from "@/components/portal/FeesWorkspace";
import { WebsiteManager } from "@/components/portal/WebsiteManager";
import { AdmissionInquiriesWorkspace } from "@/components/portal/AdmissionInquiriesWorkspace";
import { ReportsWorkspace } from "@/components/portal/ReportsWorkspace";
import { PortalErrorBoundary } from "@/components/error-boundary";
import { ChevronLeft, ChevronRight, Search } from "@/lib/lucide-react";
import { QuickSearchModal } from "@/components/portal/QuickSearchModal";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import { PortalStateProvider, usePortalNavigation, clearPortalViewStorage, clearSavedFormMarkers } from "@/components/portal/PortalStateProvider";
import { serializePortalTarget } from "@/lib/portal-navigation";

type PortalProps = { role: PortalRole; initialBranchId?: string; sessionScope?: string; initialSchoolId?: string; initialSchoolName?: string };
export function PortalClient(props: PortalProps) {
  const [scopeBranch, setScopeBranch] = useState(props.role === "principal" ? props.initialBranchId ?? "" : props.initialSchoolId ?? "assigned");
  const scope = `${props.sessionScope ?? "legacy"}:${props.role}:${scopeBranch}`;
  return <PortalStateProvider key={scope} scope={scope} role={props.role}><PortalWorkspace {...props} initialBranchId={props.role === "principal" ? scopeBranch : ""} onBranchChanged={setScopeBranch} /></PortalStateProvider>;
}
function PortalWorkspace({ role, initialBranchId = "", initialSchoolName = "Assigned branch", onBranchChanged }: PortalProps & { onBranchChanged: (branch: string) => void }) {
  const { target, navigate: navigateTarget, confirmLeave, ready, refresh, refreshing, canRefresh, refreshedAt, refreshError } = usePortalNavigation();
  const active = target.module;
  const [searchRecord, setSearchRecord] = useState<Row | undefined>();
  const [createToken, setCreateToken] = useState(0);
  const [dashboardRefresh, setDashboardRefresh] = useState(0);
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const [collapsed, setCollapsed] = useState(false);
  const [quickSearchOpen, setQuickSearchOpen] = useState(false);
  const [branches, setBranches] = useState<Array<{ id: string; name: string }>>([]);
  const [activeBranch, setActiveBranch] = useState(initialBranchId);
  const [branchSelected, setBranchSelected] = useState(role !== "principal" || Boolean(initialBranchId));
  const [branchesLoading, setBranchesLoading] = useState(role === "principal");
  const [branchError, setBranchError] = useState("");
  const [switchingBranch, setSwitchingBranch] = useState(false);
  const [loggingOut, setLoggingOut] = useState(false);

  const nav = visibleModules(role);
  const selected = modules.find((item) => item.id === active);

  useEffect(() => {
    function handleGlobalKeyDown(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setQuickSearchOpen((prev) => !prev);
      }
    }
    window.addEventListener("keydown", handleGlobalKeyDown);
    return () => window.removeEventListener("keydown", handleGlobalKeyDown);
  }, []);

  useEffect(() => {
    if (role !== "principal") return;
    fetch("/api/backend/branches")
      .then(async (response) => {
        if (!response.ok) throw new Error("Unable to load school branches. Refresh the page to retry.");
        return response.json();
      })
      .then((payload) => {
        const rows = Array.isArray(payload.data) ? payload.data : [];
        setBranches(rows.map((row: { id?: string; name?: string }) => ({ id: row.id ?? "", name: row.name ?? "Branch" })).filter((row: { id: string }) => Boolean(row.id)));
      })
      .catch((error) => setBranchError(error instanceof Error ? error.message : "Unable to load school branches."))
      .finally(() => setBranchesLoading(false));
  }, [role]);

  async function changeBranch(branchId: string) {
    if (!confirmLeave()) return;
    setSwitchingBranch(true);
    try {
      const response = await fetch("/api/branch", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ branchId }) });
      if (!response.ok) {
        const payload = await response.json().catch(() => ({})) as { error?: unknown };
        const message = typeof payload.error === "string" && payload.error.trim()
          ? payload.error
          : "Unable to switch school branch. Please try again.";
        notify(message, "error");
        return;
      }
      setActiveBranch(branchId);
      history.replaceState(history.state, "", `${location.pathname}${serializePortalTarget({ module: active, tab: target.tab }, role)}`);
      onBranchChanged(branchId);
      setBranchSelected(true);
      setDashboardRefresh((value) => value + 1);
    } catch {
      notify("Unable to switch school branch. Check your connection and try again.", "error");
    } finally {
      setSwitchingBranch(false);
    }
  }

  const navigate = (module: string, tab?: string) => {
    if (!navigateTarget({ module, ...(tab ? { tab } : {}) })) return false;
    setSearchRecord(undefined); setCreateToken(0); return true;
  };
  const createInModule = (module: string) => {
    if (navigate(module)) setCreateToken(Date.now());
  };

  const notify = useCallback((message: string, type: "success" | "error" | "info" = "success") => {
    if (type === "success") clearSavedFormMarkers();
    setToasts((prev) => [
      ...prev,
      { id: `${Date.now()}-${Math.random()}`, message, type },
    ]);
  }, []);

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  async function logout() {
    if (!confirmLeave()) return;
    setLoggingOut(true);
    try {
      const response = await fetch("/api/auth/logout", { method: "POST" });
      if (!response.ok) throw new Error("Unable to sign out.");
      clearPortalViewStorage();
      window.location.href = "/login";
    } catch {
      setLoggingOut(false);
      notify("Unable to sign out. Please try again.", "error");
    }
  }

  const roleLabel = role === "principal" ? "Principal workspace" : "Coordinator workspace";

  return (
    <main className={`portal ops-portal ${collapsed ? "collapsed" : ""}`}>
      {/* Sidebar */}
      <aside className={`sidebar ops-sidebar ${collapsed ? "collapsed" : ""}`}>
        <div className="ops-brand-row">
          <a href="/" className="portal-brand" title="Arish Ville Preschool">
            <Image
              src="/branding/arishville-logo.png"
              alt="Arish Ville Preschool"
              width={32}
              height={32}
            />
            {!collapsed && (
              <span>
                Arish Ville
                <small>Preschool</small>
              </span>
            )}
          </a>
          <button
            type="button"
            className="ops-collapse-toggle"
            onClick={() => setCollapsed((prev) => !prev)}
            title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
            aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          >
            {collapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
          </button>
        </div>

        {!collapsed && <p className="ops-role-chip">{roleLabel}</p>}

        <nav className="side-nav" aria-label="Portal navigation">
          {nav.map((id) => {
            const meta = navMeta[id];
            if (!meta) return null;
            const Icon = meta.icon;
            const label = meta.label;
            return (
              <button
                key={id}
                onClick={() => navigate(id)}
                aria-current={active === id ? "page" : undefined}
                className={active === id ? "active" : ""}
                title={label}
              >
                {typeof Icon === "function" ? <Icon size={17} /> : <span aria-hidden>•</span>}
                {!collapsed && <span>{label}</span>}
              </button>
            );
          })}
        </nav>


        <div className="ops-sidebar-status" title="SchoolDesk workspace">
          <i />
          {!collapsed && <span>SchoolDesk workspace</span>}
        </div>
      </aside>

      {/* Main content */}
      <div className="portal-main">
        <header className="portal-topbar ops-topbar">
          <PortalPageHeader role={role} title={navMeta[active]?.label ?? "Overview"} />
          <div className="ops-topbar-actions">
            {role === "principal" && branches.length > 0 && (
              <label className="branch-select">
                <span className="sr-only">Active branch</span>
                <select value={activeBranch} onChange={(event) => void changeBranch(event.target.value)} disabled={switchingBranch}>
                  <option value="" disabled>Select branch</option>
                  {branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}
                </select>
              </label>
            )}
            {role === "coordinator" && <span className="portal-branch-context">{initialSchoolName}</span>}
            <button
              className="secondary-button"
              onClick={() => setQuickSearchOpen(true)}
              title="Search across students, teachers, parents, classes, invoices, or jump to module (Ctrl+K)"
              style={{ display: "inline-flex", alignItems: "center", gap: "0.4rem" }}
            >
              <Search size={15} />
              <span>Quick Search</span>
              <kbd style={{ fontSize: "0.7rem", padding: "0.1rem 0.35rem", background: "rgba(0,0,0,0.06)", borderRadius: "4px", border: "1px solid rgba(0,0,0,0.12)", color: "#4f6575" }}>
                Ctrl K
              </kbd>
            </button>
            <button
              className="secondary-button"
              onClick={() => void refresh()}
              disabled={!ready || !canRefresh || refreshing}
              aria-busy={refreshing}
              title={refreshedAt ? `Current view refreshed at ${refreshedAt}` : "Refresh current view"}
            >
              {refreshing ? "Refreshing…" : "Refresh"}
            </button>
            <button className="secondary-button" onClick={() => void logout()} disabled={loggingOut} aria-busy={loggingOut}>
              {loggingOut ? <LoadingIndicator label="Signing out…" compact announce={false} /> : "Sign out"}
            </button>
          </div>
        </header>

        {refreshError && <p className="ops-inline-error" role="alert">{refreshError}</p>}
        <section className="portal-content ops-content" aria-busy={branchesLoading || switchingBranch}>
          {!ready || branchesLoading || switchingBranch ? (
            <PortalModuleSkeleton variant="cards" label={branchesLoading ? "Loading available school branches" : "Switching school branch"} />
          ) : role === "principal" && !branchSelected ? (
            <div className="ops-branch-gate">
              <h2>Select a branch to begin</h2>
              <p>School data is deliberately hidden until you choose the branch you want to manage.</p>
              {branchError && <p role="alert" className="ops-inline-error">{branchError}</p>}
              <select value={activeBranch} onChange={(event) => void changeBranch(event.target.value)} disabled={switchingBranch}>
                <option value="" disabled>Select branch</option>
                {branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}
              </select>
            </div>
          ) : <PortalErrorBoundary key={`${activeBranch}-${active}`}>
            {active === "overview" ? (
              <DashboardPanel
                role={role}
                onNavigate={navigate}
                onCreate={createInModule}
                refreshNonce={dashboardRefresh}
              />
            ) : active === "reports" ? (
              <ReportsWorkspace role={role} onNotify={notify} />
            ) : active === "website" ? (
              <WebsiteManager onNotify={notify} />
            ) : active === "admission_inquiries" ? (
              <AdmissionInquiriesWorkspace />
            ) : active === "fees" && role === "principal" ? (
              <FeesWorkspace onNotify={notify} initialRecord={searchRecord} />
            ) : selected ? (
              <ResourceModule
                module={selected}
                initialRecord={searchRecord}
                createToken={createToken}
                onSaved={() => setDashboardRefresh((v) => v + 1)}
                onNotify={notify}
              />
            ) : null}
          </PortalErrorBoundary>}
        </section>
      </div>

      {quickSearchOpen && (
        <QuickSearchModal
          role={role}
          onClose={() => setQuickSearchOpen(false)}
          onSelectResult={(item) => {
            if (navigate(item.targetModule)) {
              setQuickSearchOpen(false);
              setSearchRecord(item.record ? { ...item.record } : undefined);
            }
          }}
        />
      )}

      {/* Toast notifications */}
      <ToastContainer toasts={toasts} onDismiss={dismissToast} />
    </main>
  );
}

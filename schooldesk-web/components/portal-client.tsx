"use client";

import { useCallback, useEffect, useState } from "react";
import Image from "next/image";
import type { PortalRole } from "@/lib/roles";
import { visibleModules } from "@/lib/roles";
import { modules, navMeta } from "@/components/portal/types";
import type { ToastItem } from "@/components/portal/Toast";
import { ToastContainer } from "@/components/portal/Toast";
import { DashboardPanel } from "@/components/portal/DashboardPanel";
import { ResourceModule } from "@/components/portal/ResourceModule";
import { FeesWorkspace } from "@/components/portal/FeesWorkspace";
import { WebsiteManager } from "@/components/portal/WebsiteManager";
import { TickerManager } from "@/components/portal/TickerManager";
import { AdmissionInquiriesWorkspace } from "@/components/portal/AdmissionInquiriesWorkspace";
import { ReportsWorkspace } from "@/components/portal/ReportsWorkspace";
import { PortalErrorBoundary } from "@/components/error-boundary";
import { ChevronLeft, ChevronRight, Search } from "@/lib/lucide-react";
import { QuickSearchModal } from "@/components/portal/QuickSearchModal";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";

export function PortalClient({ role, initialBranchId = "" }: { role: PortalRole; initialBranchId?: string }) {
  const [active, setActive] = useState("overview");
  const [createToken, setCreateToken] = useState(0);
  const [dashboardRefresh, setDashboardRefresh] = useState(0);
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const [collapsed, setCollapsed] = useState(false);
  const [quickSearchOpen, setQuickSearchOpen] = useState(false);
  const [branches, setBranches] = useState<Array<{ id: string; name: string }>>([]);
  const [activeBranch, setActiveBranch] = useState(initialBranchId);
  const [branchSelected, setBranchSelected] = useState(role !== "principal" || Boolean(initialBranchId));
  const [branchesLoading, setBranchesLoading] = useState(role === "principal");
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
      .then((response) => response.json())
      .then((payload) => {
        const rows = Array.isArray(payload.data) ? payload.data : [];
        setBranches(rows.map((row: { id?: string; name?: string }) => ({ id: row.id ?? "", name: row.name ?? "Branch" })).filter((row: { id: string }) => Boolean(row.id)));
      })
      .catch(() => setBranches([]))
      .finally(() => setBranchesLoading(false));
  }, [role]);

  async function changeBranch(branchId: string) {
    setSwitchingBranch(true);
    try {
      const response = await fetch("/api/branch", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ branchId }) });
      if (!response.ok) return;
      setActiveBranch(branchId);
      setBranchSelected(true);
      setDashboardRefresh((value) => value + 1);
    } finally {
      setSwitchingBranch(false);
    }
  }

  const navigate = (target: string) => {
    if (!(nav as readonly string[]).includes(target)) return;
    setActive(target);
    setCreateToken(0);
  };

  const createInModule = (target: string) => {
    if (!(nav as readonly string[]).includes(target)) return;
    setActive(target);
    setCreateToken(Date.now());
  };

  const notify = useCallback((message: string, type: "success" | "error" | "info" = "success") => {
    setToasts((prev) => [
      ...prev,
      { id: `${Date.now()}-${Math.random()}`, message, type },
    ]);
  }, []);

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  async function logout() {
    setLoggingOut(true);
    try {
      await fetch("/api/auth/logout", { method: "POST" });
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
            const label = role === "coordinator" && id === "website" ? "Ticker" : meta.label;
            return (
              <button
                key={id}
                onClick={() => {
                  setActive(id);
                  setCreateToken(0);
                }}
                className={active === id ? "active" : ""}
                title={label}
              >
                {typeof Icon === "function" ? <Icon size={17} /> : <span aria-hidden>•</span>}
                {!collapsed && <span>{label}</span>}
              </button>
            );
          })}
        </nav>

        {!collapsed && role === "coordinator" && (
          <p className="finance-note">Finance is safely managed by the Principal.</p>
        )}

        <div className="ops-sidebar-status" title="SchoolDesk connected">
          <i />
          {!collapsed && <span>SchoolDesk connected</span>}
        </div>
      </aside>

      {/* Main content */}
      <div className="portal-main">
        <header className="portal-topbar ops-topbar">
          <div>
            <p>{role === "principal" ? "Principal Portal" : "Coordinator Portal"}</p>
            <h1>
              {active === "overview" ? "Operations overview" : navMeta[active]?.label}
            </h1>
          </div>
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
              onClick={() => setDashboardRefresh((v) => v + 1)}
            >
              Refresh data
            </button>
            <button className="secondary-button" onClick={() => void logout()} disabled={loggingOut} aria-busy={loggingOut}>
              {loggingOut ? <LoadingIndicator label="Signing out…" compact announce={false} /> : "Sign out"}
            </button>
          </div>
        </header>

        <section className="portal-content ops-content" aria-busy={branchesLoading || switchingBranch}>
          {branchesLoading || switchingBranch ? (
            <PortalModuleSkeleton variant="cards" label={branchesLoading ? "Loading available school branches" : "Switching school branch"} />
          ) : role === "principal" && !branchSelected ? (
            <div className="ops-branch-gate">
              <h2>Select a branch to begin</h2>
              <p>School data is deliberately hidden until you choose the branch you want to manage.</p>
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
            ) : active === "website" && role === "principal" ? (
              <WebsiteManager onNotify={notify} />
            ) : active === "website" && role === "coordinator" ? (
              <TickerManager onNotify={notify} />
            ) : active === "admission_inquiries" ? (
              <AdmissionInquiriesWorkspace />
            ) : active === "fees" && role === "principal" ? (
              <FeesWorkspace onNotify={notify} />
            ) : selected ? (
              <ResourceModule
                module={selected}
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
            setQuickSearchOpen(false);
            navigate(item.targetModule);
          }}
        />
      )}

      {/* Toast notifications */}
      <ToastContainer toasts={toasts} onDismiss={dismissToast} />
    </main>
  );
}

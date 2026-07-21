"use client";

import { useCallback, useState } from "react";
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
import { AttendanceWorkspace } from "@/components/portal/AttendanceWorkspace";
import { CommunicationsWorkspace } from "@/components/portal/CommunicationsWorkspace";
import { ReportsWorkspace } from "@/components/portal/ReportsWorkspace";
import { PortalErrorBoundary } from "@/components/error-boundary";

export function PortalClient({ role }: { role: PortalRole }) {
  const [active, setActive] = useState("overview");
  const [createToken, setCreateToken] = useState(0);
  const [dashboardRefresh, setDashboardRefresh] = useState(0);
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const nav = visibleModules(role);
  const selected = modules.find((item) => item.id === active);

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
    await fetch("/api/auth/logout", { method: "POST" });
    location.assign("/");
  }

  const roleLabel = role === "principal" ? "Principal workspace" : "Coordinator workspace";

  return (
    <main className="portal ops-portal">
      {/* Sidebar */}
      <aside className="sidebar ops-sidebar">
        <a href="/" className="portal-brand">
          <Image
            src="/branding/arishville-logo.png"
            alt="ArishVille Preschool"
            width={32}
            height={32}
          />
          <span>
            ArishVille
            <small>Preschool</small>
          </span>
        </a>

        <p className="ops-role-chip">{roleLabel}</p>

        <nav className="side-nav" aria-label="Portal navigation">
          {nav.map((id) => {
            const meta = navMeta[id];
            const Icon = meta.icon;
            return (
              <button
                key={id}
                onClick={() => {
                  setActive(id);
                  setCreateToken(0);
                }}
                className={active === id ? "active" : ""}
              >
                {typeof Icon === "function" ? <Icon size={17} /> : <span aria-hidden>•</span>}
                <span>{meta.label}</span>
              </button>
            );
          })}
        </nav>

        {role === "coordinator" && (
          <p className="finance-note">Finance is safely managed by the Principal.</p>
        )}

        <div className="ops-sidebar-status">
          <i />
          <span>SchoolDesk connected</span>
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
            <button
              className="secondary-button"
              onClick={() => setDashboardRefresh((v) => v + 1)}
            >
              Refresh data
            </button>
            <button className="secondary-button" onClick={() => void logout()}>
              Sign out
            </button>
          </div>
        </header>

        <section className="portal-content ops-content">
          <PortalErrorBoundary>
            {active === "overview" ? (
              <DashboardPanel
                role={role}
                onNavigate={navigate}
                onCreate={createInModule}
                refreshNonce={dashboardRefresh}
              />
            ) : active === "attendance" ? (
              <AttendanceWorkspace role={role} onNotify={notify} />
            ) : active === "communications" ? (
              <CommunicationsWorkspace role={role} onNotify={notify} />
            ) : active === "reports" ? (
              <ReportsWorkspace role={role} onNotify={notify} />
            ) : active === "website" && role === "principal" ? (
              <WebsiteManager onNotify={notify} />
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
          </PortalErrorBoundary>
        </section>
      </div>

      {/* Toast notifications */}
      <ToastContainer toasts={toasts} onDismiss={dismissToast} />
    </main>
  );
}

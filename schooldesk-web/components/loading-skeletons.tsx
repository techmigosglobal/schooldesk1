import Image from "next/image";

export function LoadingIndicator({
  label,
  compact = false,
  announce = true,
}: {
  label: string;
  compact?: boolean;
  announce?: boolean;
}) {
  return (
    <span
      className={`activity-indicator${compact ? " is-compact" : ""}`}
      role={announce ? "status" : undefined}
      aria-live={announce ? "polite" : undefined}
    >
      <span className="activity-spinner" aria-hidden="true" />
      <span>{label}</span>
    </span>
  );
}

export function LoginSkeleton() {
  return (
    <main className="login-page" aria-busy="true" aria-label="Preparing secure sign in">
      <section className="login-card login-skeleton-card">
        <div className="login-brand">
          <Image
            src="/branding/arishville-logo.png"
            alt=""
            width={66}
            height={66}
            priority
          />
          <span>Arish Ville Preschool</span>
        </div>
        <div className="skeleton skeleton-text login-skeleton-title" />
        <div className="skeleton skeleton-text wide" />
        <div className="login-skeleton-fields">
          <div className="skeleton skeleton-input" />
          <div className="skeleton skeleton-input" />
          <div className="skeleton skeleton-button" />
        </div>
        <LoadingIndicator label="Preparing secure access…" announce={false} />
      </section>
    </main>
  );
}

export function PortalSkeleton() {
  return (
    <main className="portal ops-portal portal-route-skeleton" aria-busy="true" aria-label="Loading SchoolDesk portal">
      <aside className="sidebar ops-sidebar">
        <div className="ops-brand-row">
          <div className="portal-brand">
            <Image
              src="/branding/arishville-logo.png"
              alt=""
              width={32}
              height={32}
              priority
            />
            <span>Arish Ville<small>Preschool</small></span>
          </div>
        </div>
        <div className="skeleton skeleton-chip" />
        <div className="portal-skeleton-nav">
          {Array.from({ length: 7 }, (_, index) => <div className="skeleton" key={index} />)}
        </div>
      </aside>
      <div className="portal-main">
        <header className="portal-topbar ops-topbar">
          <div className="portal-skeleton-heading">
            <div className="skeleton skeleton-text narrow" />
            <div className="skeleton skeleton-text wide" />
          </div>
          <div className="skeleton skeleton-button small" />
        </header>
        <section className="portal-content ops-content">
          <LoadingIndicator label="Preparing your portal…" />
          <div className="portal-skeleton-welcome">
            <div className="skeleton skeleton-text narrow" />
            <div className="skeleton skeleton-text wide" />
            <div className="skeleton skeleton-text" />
          </div>
          <div className="ops-metric-skeleton">
            {Array.from({ length: 4 }, (_, index) => <div className="skeleton skeleton-card" key={index} />)}
          </div>
          <div className="portal-skeleton-panels">
            <div className="skeleton skeleton-panel" />
            <div className="skeleton skeleton-panel" />
          </div>
        </section>
      </div>
    </main>
  );
}

export type PortalModuleSkeletonVariant =
  | "table"
  | "split"
  | "cards"
  | "reports"
  | "finance"
  | "timetable";

export function PortalModuleSkeleton({
  variant = "table",
  rows = 6,
  label = "Loading module data",
}: {
  variant?: PortalModuleSkeletonVariant;
  rows?: number;
  label?: string;
}) {
  const metricCount = variant === "finance" || variant === "reports" ? 4 : 3;

  return (
    <div
      className={`portal-module-loading is-${variant}`}
      role="status"
      aria-busy="true"
      aria-label={label}
    >
      <LoadingIndicator label={label} announce={false} />
      <div className="portal-module-loading-toolbar" aria-hidden="true">
        <div className="skeleton skeleton-input" />
        <div className="skeleton skeleton-button small" />
        <div className="skeleton skeleton-button small" />
      </div>

      {(variant === "finance" || variant === "reports" || variant === "cards") && (
        <div className="portal-module-loading-metrics" aria-hidden="true">
          {Array.from({ length: metricCount }, (_, index) => (
            <div className="skeleton skeleton-card" key={index} />
          ))}
        </div>
      )}

      {variant === "split" || variant === "cards" ? (
        <div className="portal-module-loading-split" aria-hidden="true">
          <div className="skeleton skeleton-panel" />
          <div>
            <div className="skeleton skeleton-text wide" />
            <div className="skeleton skeleton-text narrow" />
            <div className="portal-module-loading-card-grid">
              {Array.from({ length: 4 }, (_, index) => (
                <div className="skeleton skeleton-card" key={index} />
              ))}
            </div>
          </div>
        </div>
      ) : variant === "timetable" ? (
        <div className="portal-module-loading-timetable" aria-hidden="true">
          <div className="skeleton skeleton-text wide" />
          <div className="portal-module-loading-day-row">
            {Array.from({ length: 6 }, (_, index) => (
              <div className="skeleton skeleton-chip" key={index} />
            ))}
          </div>
          <div className="skeleton skeleton-panel" />
        </div>
      ) : variant === "reports" ? (
        <div className="portal-module-loading-report-grid" aria-hidden="true">
          {Array.from({ length: 6 }, (_, index) => (
            <div className="skeleton skeleton-card" key={index} />
          ))}
          <div className="skeleton skeleton-panel portal-module-loading-wide" />
        </div>
      ) : (
        <div className="portal-module-loading-table" aria-hidden="true">
          <div className="skeleton portal-module-loading-table-head" />
          {Array.from({ length: rows }, (_, index) => (
            <div className="portal-module-loading-table-row" key={index}>
              <div className="skeleton" />
              <div className="skeleton" />
              <div className="skeleton" />
              <div className="skeleton" />
            </div>
          ))}
        </div>
      )}

      <span className="sr-only">Please wait while current school records are prepared.</span>
    </div>
  );
}

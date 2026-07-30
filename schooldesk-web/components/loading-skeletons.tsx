import Image from "next/image";

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
        <p className="skeleton-status">Preparing secure access&hellip;</p>
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

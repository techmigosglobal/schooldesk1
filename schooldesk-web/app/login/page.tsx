import Link from "next/link";
import Image from "next/image";

export default function LeadershipLoginSelectionPage() {
  return (
    <main className="login-page">
      <section className="login-card login-role-card">
        <Link className="login-brand" href="/" aria-label="Back to Arish Ville Preschool website">
          <Image
            src="/branding/arishville-logo.png"
            alt="Arish Ville Preschool"
            width={66}
            height={66}
          />
          <span>Arish Ville Preschool</span>
        </Link>

        <p className="login-kicker">SchoolDesk leadership access</p>
        <h1>Welcome back</h1>
        <p className="login-lead">Choose your workspace to continue securely. Your role controls what you can access.</p>

        <div className="login-role-grid">
          <Link className="login-role-option" href="/login/principal">
            <span className="login-role-eyebrow">Leadership workspace</span>
            <strong>Principal Portal <b aria-hidden="true">→</b></strong>
            <span>Finance, website, reports, and full leadership operations.</span>
          </Link>
          <Link className="login-role-option" href="/login/coordinator">
            <span className="login-role-eyebrow">Operations workspace</span>
            <strong>Coordinator Portal <b aria-hidden="true">→</b></strong>
            <span>Daily operations, class planning, admissions, and academic reporting.</span>
          </Link>
        </div>
        <div className="login-return"><Link href="/">← Back to school website</Link><span>Only Principal and Coordinator accounts can use this website.</span></div>
      </section>
    </main>
  );
}

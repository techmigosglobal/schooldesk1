import Link from "next/link";
import Image from "next/image";

export default function StaffLoginSelectionPage() {
  return (
    <main className="login-page">
      <section className="login-card login-role-card">
        <Link className="login-brand" href="/" aria-label="Back to ArishVille Preschool website">
          <Image
            src="/branding/arishville-logo.png"
            alt="ArishVille Preschool"
            width={66}
            height={66}
          />
          <span>ArishVille Preschool</span>
        </Link>

        <p className="login-kicker">SchoolDesk staff access</p>
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
            <span>Daily school operations, attendance, classes, and communications.</span>
          </Link>
        </div>
        <div className="login-return"><Link href="/">← Back to school website</Link><span>Need a different staff role? Please contact the principal.</span></div>
      </section>
    </main>
  );
}

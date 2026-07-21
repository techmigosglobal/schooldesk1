import Link from "next/link";
import Image from "next/image";

export default function StaffLoginSelectionPage() {
  return (
    <main className="login-page">
      <section className="login-card login-role-card">
        <a className="login-brand" href="/">
          <Image
            src="/branding/arishville-logo.png"
            alt="ArishVille Preschool"
            width={66}
            height={66}
          />
          <span>ArishVille Preschool</span>
        </a>

        <h1>Staff Portal Access</h1>
        <p>Select the portal you want to sign in to.</p>

        <div className="login-role-grid">
          <Link className="login-role-option" href="/login/principal">
            <strong>Principal Portal</strong>
            <span>Finance, website, reports, and full leadership operations.</span>
          </Link>
          <Link className="login-role-option" href="/login/coordinator">
            <strong>Coordinator Portal</strong>
            <span>Daily school operations, attendance, classes, and communications.</span>
          </Link>
        </div>
      </section>
    </main>
  );
}

"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Building2,
  Camera,
  CheckCircle2,
  CircleAlert,
  Globe2,
  Info,
  Pencil,
  RefreshCw,
  School,
  ShieldCheck,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import { usePortalRefresh } from "./use-portal-refresh";
import { usePortalTab } from "./PortalStateProvider";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import { api, rowsFrom, stringValue } from "./utils";

type BranchItem = {
  id: string;
  name: string;
  branch_code?: string;
  city?: string;
  state?: string;
  logo_url?: string;
  multi_branch_enabled?: boolean;
};

export function SchoolProfileWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [tab, setTab] = usePortalTab<"details" | "branding" | "branches">(
    "school_profile",
    "details"
  );
  const [school, setSchool] = useState<Row>({});
  const [branches, setBranches] = useState<BranchItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const [uploadingSignature, setUploadingSignature] = useState(false);
  const [error, setError] = useState("");

  // Logo & Signature file state
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [logoPreviewUrl, setLogoPreviewUrl] = useState<string>("");
  const [signatureFile, setSignatureFile] = useState<File | null>(null);
  const [signaturePreviewUrl, setSignaturePreviewUrl] = useState<string>("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [schoolRes, branchesRes] = await Promise.all([
        api("schools/current").catch(() => ({})),
        api("branches").catch(() => []),
      ]);
      setSchool((schoolRes as Row) || {});
      setBranches((Array.isArray(branchesRes) ? branchesRes : []) as BranchItem[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load school profile");
    } finally {
      setLoading(false);
    }
  }, []);

  usePortalRefresh(load);

  useEffect(() => {
    void load();
  }, [load]);

  // Handle school details save
  const handleSaveDetails = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setSaving(true);
    setError("");
    const form = new FormData(e.currentTarget);
    const payload: Record<string, string> = {};

    for (const [key, value] of form.entries()) {
      if (typeof value === "string") {
        payload[key] = value.trim();
      }
    }

    try {
      const updated = await api("schools/current", {
        method: "PATCH",
        body: JSON.stringify(payload),
      });
      setSchool((updated as Row) || school);
      onNotify("School profile and affiliation details updated successfully", "success");
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Failed to update school profile";
      setError(msg);
      onNotify(msg, "error");
    } finally {
      setSaving(false);
    }
  };

  // Handle Logo Upload
  const handleUploadLogo = async () => {
    if (!logoFile) return;
    setUploadingLogo(true);
    setError("");

    const fd = new FormData();
    fd.append("logo", logoFile);

    try {
      const res = await api("schools/current/logo", {
        method: "POST",
        body: fd,
      });
      const newLogoUrl = (res as { logo_url?: string })?.logo_url;
      setSchool((prev) => ({ ...prev, logo_url: newLogoUrl }));
      setLogoFile(null);
      setLogoPreviewUrl("");
      onNotify("School official logo updated successfully", "success");
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Failed to upload school logo";
      setError(msg);
      onNotify(msg, "error");
    } finally {
      setUploadingLogo(false);
    }
  };

  // Handle Digital Signature Upload
  const handleUploadSignature = async () => {
    if (!signatureFile) return;
    setUploadingSignature(true);
    setError("");

    const fd = new FormData();
    fd.append("signature", signatureFile);

    try {
      const res = await api("schools/current/signature", {
        method: "POST",
        body: fd,
      });
      const newSigUrl = (res as { authorized_signature_url?: string })?.authorized_signature_url;
      setSchool((prev) => ({
        ...prev,
        authorized_signature_url: newSigUrl,
        authorized_signature_path: "configured",
      }));
      setSignatureFile(null);
      setSignaturePreviewUrl("");
      onNotify("Principal authorized digital signature uploaded successfully", "success");
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Failed to upload digital signature";
      setError(msg);
      onNotify(msg, "error");
    } finally {
      setUploadingSignature(false);
    }
  };

  return (
    <section className="ops-module school-profile-workspace" aria-busy={loading}>
      <div className="directory-context-bar" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem" }}>
        <div>
          <p>
            <strong>School Governance &amp; Profile</strong> · Institutional accreditation, official branding, and Principal digital signature authority.
          </p>
        </div>
        <div>
          <button
            type="button"
            className="btn-secondary"
            onClick={() => void load()}
            style={{ fontSize: "0.85rem", display: "inline-flex", alignItems: "center", gap: "0.35rem", padding: "0.4rem 0.75rem" }}
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="ops-inline-error" role="alert" style={{ margin: "1rem 0" }}>
          <CircleAlert size={16} />
          {error}
        </div>
      )}

      {/* Tabs */}
      <nav className="finance-tabs" aria-label="School profile views">
        <button
          type="button"
          className={tab === "details" ? "active" : ""}
          onClick={() => setTab("details")}
        >
          School Details
        </button>
        <button
          type="button"
          className={tab === "branding" ? "active" : ""}
          onClick={() => setTab("branding")}
        >
          Branding &amp; Signatures
        </button>
        <button
          type="button"
          className={tab === "branches" ? "active" : ""}
          onClick={() => setTab("branches")}
        >
          Branch Governance ({branches.length})
        </button>
      </nav>

      {loading ? (
        <PortalModuleSkeleton variant="cards" label="Loading school profile" />
      ) : tab === "details" ? (
        /* TAB 1: DETAILS & ACCREDITATION */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.75rem" }}>
          <div style={{ display: "flex", gap: "1rem", alignItems: "center", marginBottom: "1.5rem" }}>
            <School size={28} style={{ color: "#0e5ea8" }} />
            <div>
              <h3 style={{ margin: 0, fontSize: "1.2rem", fontWeight: 700 }}>
                {stringValue(school.name || "School Profile")}
              </h3>
              <p style={{ margin: "0.2rem 0 0", color: "var(--ops-muted)", fontSize: "0.85rem" }}>
                Update institutional identification, educational board affiliation, and official contact channels.
              </p>
            </div>
          </div>

          <form onSubmit={handleSaveDetails}>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: "1.25rem" }}>
              {/* Institutional Name */}
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  School Name:
                </label>
                <input
                  name="name"
                  type="text"
                  required
                  defaultValue={stringValue(school.name)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>

              {/* Affiliation Board */}
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Affiliation / Educational Board:
                </label>
                <input
                  name="affiliation_board"
                  type="text"
                  placeholder="e.g. CBSE, ICSE, Cambridge, State Board"
                  defaultValue={stringValue(school.affiliation_board)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>

              {/* Affiliation Number */}
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Affiliation / Recognition Number:
                </label>
                <input
                  name="affiliation_number"
                  type="text"
                  placeholder="e.g. CBSE/AFF/3630129"
                  defaultValue={stringValue(school.affiliation_number)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>

              {/* Registration Number */}
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  State / Trust Registration No:
                </label>
                <input
                  name="registration_no"
                  type="text"
                  placeholder="e.g. REG-TS-HYD-2024-889"
                  defaultValue={stringValue(school.registration_no || school.registration_number)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>

              {/* Official Phone */}
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Official Phone:
                </label>
                <input
                  name="phone"
                  type="text"
                  placeholder="+91 98765 43210"
                  defaultValue={stringValue(school.phone)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>

              {/* Official Email */}
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Official Email:
                </label>
                <input
                  name="email"
                  type="email"
                  placeholder="principal@arishville.com"
                  defaultValue={stringValue(school.email)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>

              {/* Website */}
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Official Website:
                </label>
                <input
                  name="website"
                  type="text"
                  placeholder="https://arishville.com"
                  defaultValue={stringValue(school.website)}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>

              {/* Timezone */}
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Operational Timezone:
                </label>
                <input
                  name="timezone"
                  type="text"
                  readOnly
                  defaultValue={stringValue(school.timezone || "Asia/Kolkata")}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem", background: "var(--ops-surface-subtle, #f8fafc)" }}
                />
              </div>
            </div>

            {/* Campus Address */}
            <div style={{ marginTop: "1.25rem" }}>
              <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                Campus Street Address:
              </label>
              <textarea
                name="address"
                rows={2}
                defaultValue={stringValue(school.address)}
                placeholder="Plot No. 42, Mathrusree Nagar, Miyapur"
                className="ops-search-input"
                style={{ width: "100%", fontSize: "0.875rem", resize: "vertical" }}
              />
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: "1rem", marginTop: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  City:
                </label>
                <input
                  name="city"
                  type="text"
                  defaultValue={stringValue(school.city || "Hyderabad")}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  State:
                </label>
                <input
                  name="state"
                  type="text"
                  defaultValue={stringValue(school.state || "Telangana")}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Postal Code:
                </label>
                <input
                  name="postal_code"
                  type="text"
                  defaultValue={stringValue(school.postal_code || "500049")}
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.875rem" }}
                />
              </div>
            </div>

            {role === "principal" && (
              <div style={{ marginTop: "1.75rem", display: "flex", justifyContent: "flex-end" }}>
                <button
                  type="submit"
                  className="btn-primary"
                  disabled={saving}
                  style={{ padding: "0.55rem 1.25rem", fontSize: "0.9rem" }}
                >
                  {saving ? "Saving Changes..." : "Save Institutional Profile"}
                </button>
              </div>
            )}
          </form>
        </div>
      ) : tab === "branding" ? (
        /* TAB 2: BRANDING & DIGITAL SIGNATURE */
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "1.5rem" }}>
          {/* LOGO CARD */}
          <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.75rem" }}>
            <div style={{ display: "flex", gap: "0.75rem", alignItems: "center", marginBottom: "1rem" }}>
              <Camera size={22} style={{ color: "#0e5ea8" }} />
              <h3 style={{ margin: 0, fontSize: "1.1rem", fontWeight: 700 }}>Official School Logo</h3>
            </div>
            <p style={{ fontSize: "0.85rem", color: "var(--ops-muted)", marginBottom: "1.25rem", lineHeight: 1.5 }}>
              The high-resolution school logo appears on student ID cards, automated fee receipts, parent notifications, and the public portal banner.
            </p>

            {/* Current Logo Preview */}
            <div
              style={{
                display: "flex",
                justifyContent: "center",
                alignItems: "center",
                minHeight: "140px",
                background: "var(--ops-surface-subtle, #f8fafc)",
                borderRadius: "8px",
                border: "1px dashed var(--ops-border, #cbd5e1)",
                padding: "1rem",
                marginBottom: "1.25rem",
              }}
            >
              {logoPreviewUrl ? (
                <img
                  src={logoPreviewUrl}
                  alt="New Logo Preview"
                  style={{ maxHeight: "120px", maxWidth: "100%", objectFit: "contain" }}
                />
              ) : school.logo_url ? (
                <img
                  src={stringValue(school.logo_url)}
                  alt="Current School Logo"
                  style={{ maxHeight: "120px", maxWidth: "100%", objectFit: "contain" }}
                />
              ) : (
                <div style={{ textAlign: "center", color: "var(--ops-muted)" }}>
                  <Building2 size={36} style={{ margin: "0 auto 0.5rem", opacity: 0.5 }} />
                  <span style={{ fontSize: "0.85rem" }}>No custom logo uploaded yet</span>
                </div>
              )}
            </div>

            {/* Logo file picker */}
            <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
              <input
                type="file"
                accept="image/png,image/jpeg,image/webp"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) {
                    setLogoFile(file);
                    setLogoPreviewUrl(URL.createObjectURL(file));
                  }
                }}
                style={{ fontSize: "0.85rem" }}
              />
              <button
                type="button"
                className="btn-primary"
                onClick={handleUploadLogo}
                disabled={uploadingLogo || !logoFile}
                style={{ alignSelf: "flex-start", padding: "0.45rem 1rem", fontSize: "0.85rem" }}
              >
                {uploadingLogo ? "Uploading Logo..." : "Upload New School Logo"}
              </button>
            </div>
          </div>

          {/* PRINCIPAL AUTHORIZED DIGITAL SIGNATURE CARD */}
          <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.75rem" }}>
            <div style={{ display: "flex", gap: "0.75rem", alignItems: "center", marginBottom: "1rem" }}>
              <ShieldCheck size={22} style={{ color: "#16a34a" }} />
              <h3 style={{ margin: 0, fontSize: "1.1rem", fontWeight: 700 }}>Principal Digital Signature</h3>
            </div>
            <p style={{ fontSize: "0.85rem", color: "var(--ops-muted)", marginBottom: "1.25rem", lineHeight: 1.5 }}>
              Authorized digital signature used for secure automated stamping on fee receipts, generated student ID cards, bonafide certificates, and admission letters.
            </p>

            {/* Signature Preview */}
            <div
              style={{
                display: "flex",
                justifyContent: "center",
                alignItems: "center",
                minHeight: "140px",
                background: "var(--ops-surface-subtle, #f8fafc)",
                borderRadius: "8px",
                border: "1px dashed var(--ops-border, #cbd5e1)",
                padding: "1rem",
                marginBottom: "1.25rem",
              }}
            >
              {signaturePreviewUrl ? (
                <img
                  src={signaturePreviewUrl}
                  alt="New Signature Preview"
                  style={{ maxHeight: "100px", maxWidth: "100%", objectFit: "contain" }}
                />
              ) : school.authorized_signature_url ? (
                <div style={{ textAlign: "center" }}>
                  <img
                    src={stringValue(school.authorized_signature_url)}
                    alt="Active Principal Signature"
                    style={{ maxHeight: "100px", maxWidth: "100%", objectFit: "contain" }}
                  />
                  <div style={{ fontSize: "0.75rem", color: "#16a34a", marginTop: "0.5rem", fontWeight: 600 }}>
                    <CheckCircle2 size={12} style={{ display: "inline", verticalAlign: "middle", marginRight: "4px" }} />
                    Active Authorized Signature
                  </div>
                </div>
              ) : (
                <div style={{ textAlign: "center", color: "var(--ops-muted)" }}>
                  <Pencil size={32} style={{ margin: "0 auto 0.5rem", opacity: 0.5 }} />
                  <span style={{ fontSize: "0.85rem" }}>No authorized digital signature registered</span>
                </div>
              )}
            </div>

            {/* Signature File Picker */}
            <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
              <label style={{ fontSize: "0.8rem", color: "var(--ops-muted)" }}>
                Upload a transparent PNG signature file (Max 5 MB):
              </label>
              <input
                type="file"
                accept="image/png,image/jpeg,image/webp"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) {
                    setSignatureFile(file);
                    setSignaturePreviewUrl(URL.createObjectURL(file));
                  }
                }}
                style={{ fontSize: "0.85rem" }}
              />
              <button
                type="button"
                className="btn-primary"
                onClick={handleUploadSignature}
                disabled={uploadingSignature || !signatureFile}
                style={{ alignSelf: "flex-start", padding: "0.45rem 1rem", fontSize: "0.85rem", background: "#16a34a", borderColor: "#15803d" }}
              >
                {uploadingSignature ? "Securing Signature..." : "Save Authorized Signature"}
              </button>
            </div>
          </div>
        </div>
      ) : (
        /* TAB 3: BRANCH GOVERNANCE */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.75rem" }}>
          <div style={{ display: "flex", gap: "0.75rem", alignItems: "center", marginBottom: "1rem" }}>
            <Building2 size={24} style={{ color: "#0e5ea8" }} />
            <div>
              <h3 style={{ margin: 0, fontSize: "1.1rem", fontWeight: 700 }}>Network Campuses &amp; Branches</h3>
              <p style={{ margin: "0.2rem 0 0", color: "var(--ops-muted)", fontSize: "0.85rem" }}>
                Multi-branch institutional scoping. The web portal automatically filters student records, attendance, and fees based on your active branch.
              </p>
            </div>
          </div>

          <div className="ops-table-wrap" style={{ overflowX: "auto", marginTop: "1rem" }}>
            <table className="ops-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr style={{ background: "var(--ops-surface-subtle, #f8fafc)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                  <th style={{ padding: "0.75rem 1rem" }}>Campus / Branch</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Branch Code</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Location</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "center" }}>Multi-Branch Status</th>
                </tr>
              </thead>
              <tbody>
                {branches.length === 0 ? (
                  <tr>
                    <td colSpan={4} style={{ textAlign: "center", padding: "2rem", color: "var(--ops-muted)" }}>
                      Single campus active: {stringValue(school.name || "Main Campus")}
                    </td>
                  </tr>
                ) : (
                  branches.map((b) => (
                    <tr key={b.id} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                      <td style={{ padding: "0.75rem 1rem", fontWeight: 600 }}>
                        {b.name}
                        {b.id === school.id && (
                          <span
                            style={{
                              marginLeft: "0.5rem",
                              padding: "0.15rem 0.5rem",
                              borderRadius: "4px",
                              fontSize: "0.7rem",
                              background: "#dcfce7",
                              color: "#166534",
                              fontWeight: 700,
                            }}
                          >
                            Current
                          </span>
                        )}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", color: "var(--ops-muted)" }}>
                        {b.branch_code || "MAIN"}
                      </td>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        {b.city || "Hyderabad"}, {b.state || "Telangana"}
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "center" }}>
                        <span
                          style={{
                            padding: "0.2rem 0.5rem",
                            borderRadius: "9999px",
                            fontSize: "0.75rem",
                            fontWeight: 600,
                            background: "#eff6ff",
                            color: "#1e40af",
                          }}
                        >
                          Connected
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </section>
  );
}

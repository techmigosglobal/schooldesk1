"use client";

import { useRef } from "react";
import { Building2, Printer, ShieldCheck, X } from "@/lib/lucide-react";
import { Dialog } from "./Dialog";
import type { Row } from "./types";
import { displayName, nested, stringValue } from "./utils";

type StudentIdCardModalProps = {
  student: Row;
  school?: Row;
  onClose: () => void;
};

export function StudentIdCardModal({
  student,
  school,
  onClose,
}: StudentIdCardModalProps) {
  const cardRef = useRef<HTMLDivElement>(null);

  const studentName = displayName(student);
  const admissionNo = stringValue(student.admission_number || student.student_id_number || "—");
  const section = nested(student, "section");
  const grade = nested(section, "grade");
  const className = [stringValue(grade.grade_name ?? grade.name), stringValue(section.section_name ?? section.name)]
    .filter(Boolean)
    .join(" - ") || "Class";
  const dob = stringValue(student.date_of_birth || student.dob || "—");
  const bloodGroup = stringValue(student.blood_group || "—");
  const photoUrl = stringValue(student.photo_url || student.photo || student.avatar);

  // Parents
  const guardians = Array.isArray(student.guardians) ? (student.guardians as Row[]) : [];
  const primaryGuardian = guardians.find((g) => g.is_primary) || guardians[0] || {};
  const parentName = stringValue(primaryGuardian.full_name || primaryGuardian.name || "Guardian");
  const parentPhone = stringValue(primaryGuardian.phone || student.emergency_contact_phone || "—");

  // School
  const schoolName = stringValue(school?.name || "Arish Ville Preschool");
  const schoolLogo = stringValue(school?.logo_url);
  const signatureUrl = stringValue(school?.authorized_signature_url);
  const schoolAddress = stringValue(school?.address || "Miyapur, Hyderabad, Telangana");
  const affiliationNo = stringValue(school?.affiliation_number || school?.registration_no || "CBSE/2026/HYD");

  const handlePrint = () => {
    window.print();
  };

  return (
    <Dialog
      kicker="Credential Verification"
      title={`Student Identity Card · ${studentName}`}
      onClose={onClose}
    >
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "1.5rem" }}>
        {/* Printable ID Card Container */}
        <div
          ref={cardRef}
          className="printable-student-id-card"
          style={{
            width: "320px",
            height: "480px",
            background: "#ffffff",
            borderRadius: "12px",
            boxShadow: "0 8px 24px rgba(0,0,0,0.12)",
            border: "2px solid #0e5ea8",
            overflow: "hidden",
            display: "flex",
            flexDirection: "column",
            position: "relative",
            fontFamily: "system-ui, -apple-system, sans-serif",
          }}
        >
          {/* Card Top Header */}
          <div
            style={{
              background: "linear-gradient(135deg, #0e5ea8 0%, #1e40af 100%)",
              color: "#ffffff",
              padding: "0.75rem",
              textAlign: "center",
              borderBottom: "3px solid #f59e0b",
            }}
          >
            {schoolLogo ? (
              <img
                src={schoolLogo}
                alt="Logo"
                style={{ height: "32px", maxHeight: "32px", objectFit: "contain", margin: "0 auto 0.25rem", display: "block" }}
              />
            ) : (
              <Building2 size={24} style={{ margin: "0 auto 0.25rem", display: "block" }} />
            )}
            <div style={{ fontSize: "0.95rem", fontWeight: 800, textTransform: "uppercase", letterSpacing: "0.5px" }}>
              {schoolName}
            </div>
            <div style={{ fontSize: "0.65rem", opacity: 0.9 }}>
              Affiliation No: {affiliationNo} · Academic Year 2026–27
            </div>
          </div>

          {/* Card Body */}
          <div style={{ padding: "0.75rem 1rem", flex: 1, display: "flex", flexDirection: "column", alignItems: "center" }}>
            {/* Student Photo */}
            <div
              style={{
                width: "90px",
                height: "90px",
                borderRadius: "50%",
                border: "3px solid #0e5ea8",
                overflow: "hidden",
                background: "#f1f5f9",
                marginBottom: "0.5rem",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              {photoUrl ? (
                <img src={photoUrl} alt={studentName} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
              ) : (
                <span style={{ fontSize: "2rem", fontWeight: 700, color: "#0e5ea8" }}>
                  {studentName.slice(0, 1)}
                </span>
              )}
            </div>

            {/* Student Name */}
            <div style={{ fontSize: "1.1rem", fontWeight: 800, color: "#1e293b", textAlign: "center", lineHeight: 1.2 }}>
              {studentName}
            </div>
            <div
              style={{
                fontSize: "0.75rem",
                fontWeight: 700,
                color: "#0e5ea8",
                background: "#eff6ff",
                padding: "0.15rem 0.6rem",
                borderRadius: "9999px",
                marginTop: "0.25rem",
                marginBottom: "0.75rem",
              }}
            >
              CLASS: {className}
            </div>

            {/* Key Value Details Grid */}
            <div style={{ width: "100%", fontSize: "0.75rem", display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.4rem 0.5rem", borderTop: "1px solid #e2e8f0", paddingTop: "0.6rem" }}>
              <div>
                <span style={{ color: "#64748b", display: "block", fontSize: "0.65rem" }}>ADMISSION NO</span>
                <span style={{ fontWeight: 700, color: "#0f172a" }}>{admissionNo}</span>
              </div>
              <div>
                <span style={{ color: "#64748b", display: "block", fontSize: "0.65rem" }}>BLOOD GROUP</span>
                <span style={{ fontWeight: 700, color: "#dc2626" }}>{bloodGroup}</span>
              </div>
              <div>
                <span style={{ color: "#64748b", display: "block", fontSize: "0.65rem" }}>DATE OF BIRTH</span>
                <span style={{ fontWeight: 600, color: "#0f172a" }}>{dob}</span>
              </div>
              <div>
                <span style={{ color: "#64748b", display: "block", fontSize: "0.65rem" }}>EMERGENCY CONTACT</span>
                <span style={{ fontWeight: 700, color: "#0f172a" }}>{parentPhone}</span>
              </div>
            </div>

            {/* Parent Info */}
            <div style={{ width: "100%", marginTop: "0.5rem", fontSize: "0.7rem", color: "#475569", textAlign: "center" }}>
              Guardian: <strong>{parentName}</strong>
            </div>

            {/* Signature & Seal Footer */}
            <div style={{ width: "100%", marginTop: "auto", display: "flex", justifyContent: "space-between", alignItems: "flex-end", borderTop: "1px dashed #cbd5e1", paddingTop: "0.5rem" }}>
              <div style={{ fontSize: "0.6rem", color: "#64748b", maxWidth: "160px", lineHeight: 1.2 }}>
                {schoolAddress}
              </div>
              <div style={{ textAlign: "center", minWidth: "90px" }}>
                {signatureUrl ? (
                  <img
                    src={signatureUrl}
                    alt="Principal Signature"
                    style={{ height: "30px", maxHeight: "30px", objectFit: "contain", margin: "0 auto" }}
                  />
                ) : (
                  <div style={{ height: "24px", fontStyle: "italic", fontSize: "0.75rem", color: "#0e5ea8" }}>
                    Principal
                  </div>
                )}
                <div style={{ borderTop: "1px solid #94a3b8", fontSize: "0.6rem", fontWeight: 700, color: "#1e293b", marginTop: "2px" }}>
                  Principal Signature
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Modal Controls */}
        <div style={{ display: "flex", gap: "1rem" }}>
          <button
            type="button"
            className="btn-primary"
            onClick={handlePrint}
            style={{ display: "inline-flex", alignItems: "center", gap: "0.4rem", padding: "0.5rem 1.25rem", fontSize: "0.875rem" }}
          >
            <Printer size={16} /> Print Official ID Card
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={onClose}
            style={{ padding: "0.5rem 1rem", fontSize: "0.875rem" }}
          >
            Close
          </button>
        </div>
      </div>
    </Dialog>
  );
}

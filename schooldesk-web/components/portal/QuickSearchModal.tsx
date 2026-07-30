"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Building2,
  CalendarClock,
  ChartNoAxesCombined,
  GraduationCap,
  HeartHandshake,
  Images,
  LayoutDashboard,
  Search,
  UserCog,
  WalletCards,
  X,
} from "@/lib/lucide-react";
import type { PortalRole } from "@/lib/roles";
import { LoadingIndicator } from "@/components/loading-skeletons";
import type { Row } from "./types";
import { api, displayName, nested, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";

export type SearchResultItem = {
  id: string;
  category: "navigation" | "student" | "parent" | "teacher" | "class" | "invoice";
  title: string;
  subtitle: string;
  badge?: string;
  targetModule: string;
  record?: Row;
};

export function QuickSearchModal({
  role,
  onClose,
  onSelectResult,
}: {
  role: PortalRole;
  onClose: () => void;
  onSelectResult: (item: SearchResultItem) => void;
}) {
  const [query, setQuery] = useState("");
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [data, setData] = useState<{
    students: Row[];
    parents: Row[];
    teachers: Row[];
    classes: Row[];
    invoices: Row[];
  }>({
    students: [],
    parents: [],
    teachers: [],
    classes: [],
    invoices: [],
  });
  const [loading, setLoading] = useState(true);
  const inputRef = useRef<HTMLInputElement>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [stRes, pRes, tRes, cRes, invRes] = await Promise.all([
        api("students?page=1&page_size=100").catch(() => []),
        api("users?role=parent&page=1&page_size=100").catch(() => []),
        api("staff?page=1&page_size=100").catch(() => []),
        api("principal/classes").catch(() => []),
        role === "principal" ? api("fees/invoices?page=1&page_size=100").catch(() => []) : Promise.resolve([]),
      ]);

      setData({
        students: rowsFrom(stRes),
        parents: rowsFrom(pRes),
        teachers: rowsFrom(tRes),
        classes: rowsFrom(cRes),
        invoices: rowsFrom(invRes),
      });
    } catch {
      // Ignore load errors for search modal
    } finally {
      setLoading(false);
    }
  }, [role]);

  useEffect(() => {
    void loadData();
    const timer = setTimeout(() => inputRef.current?.focus(), 50);
    return () => clearTimeout(timer);
  }, [loadData]);

  const navItems: SearchResultItem[] = useMemo(() => {
    const list: SearchResultItem[] = [
      { id: "nav-overview", category: "navigation", title: "Overview Dashboard", subtitle: "Operations metrics & system health", badge: "Module", targetModule: "overview" },
      { id: "nav-students", category: "navigation", title: "Students Directory", subtitle: "Admissions & learner profiles", badge: "Module", targetModule: "students" },
      { id: "nav-parents", category: "navigation", title: "Parents Directory", subtitle: "Family contacts & portal accounts", badge: "Module", targetModule: "parents" },
      { id: "nav-teachers", category: "navigation", title: "Teachers Directory", subtitle: "Educator profiles & assignments", badge: "Module", targetModule: "teachers" },
      { id: "nav-classes", category: "navigation", title: "Classes & Subjects", subtitle: "Grade sections & curriculum mapping", badge: "Module", targetModule: "classes" },
      { id: "nav-timetable", category: "navigation", title: "Timetables", subtitle: "Class schedules & auto-generator", badge: "Module", targetModule: "timetable" },
    ];
    if (role === "principal") {
      list.push({ id: "nav-fees", category: "navigation", title: "Fees & Ledger", subtitle: "Invoicing, payments & late fines", badge: "Module", targetModule: "fees" });
    }
    list.push({ id: "nav-reports", category: "navigation", title: "Reports & Exports", subtitle: "Analytics & CSV/PDF exports", badge: "Module", targetModule: "reports" });
    if (role === "principal") {
      list.push({ id: "nav-website", category: "navigation", title: "Gallery & Public Website", subtitle: "Curated photos & homepage copy", badge: "Module", targetModule: "website" });
    }
    return list;
  }, [role]);

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    const matched: SearchResultItem[] = [];

    // Filter navigation
    if (q) {
      navItems.forEach((nav) => {
        if (nav.title.toLowerCase().includes(q) || nav.subtitle.toLowerCase().includes(q)) {
          matched.push(nav);
        }
      });
    } else {
      matched.push(...navItems.slice(0, 4));
    }

    // Filter Students
    data.students.forEach((st) => {
      const name = displayName(st);
      const stId = stringValue(st.student_id_number);
      const section = nested(st, "section");
      const gradeName = stringValue(nested(section, "grade").grade_name);
      const secName = stringValue(section.section_name ?? section.name);
      const classLabel = [gradeName, secName].filter(Boolean).join(" - ");

      if (!q || [name, stId, classLabel].some((v) => v.toLowerCase().includes(q))) {
        matched.push({
          id: `st-${st.id}`,
          category: "student",
          title: name,
          subtitle: `Student ID: ${stId || "—"} · ${classLabel || "Unassigned"}`,
          badge: "Student",
          targetModule: "students",
          record: st,
        });
      }
    });

    // Filter Parents
    data.parents.forEach((p) => {
      const name = stringValue(p.name || p.username);
      const username = stringValue(p.username);
      const phone = stringValue(p.phone);
      const email = stringValue(p.email);

      if (!q || [name, username, phone, email].some((v) => v.toLowerCase().includes(q))) {
        matched.push({
          id: `p-${p.id}`,
          category: "parent",
          title: name,
          subtitle: `@${username} · ${phone || email || "Parent"}`,
          badge: "Parent",
          targetModule: "parents",
          record: p,
        });
      }
    });

    // Filter Teachers
    data.teachers.forEach((t) => {
      const name = displayName(t);
      const code = stringValue(t.staff_code);
      const designation = stringValue(t.designation || "Teacher");

      if (!q || [name, code, designation].some((v) => v.toLowerCase().includes(q))) {
        matched.push({
          id: `t-${t.id}`,
          category: "teacher",
          title: name,
          subtitle: `Emp ID: ${code || "—"} · ${designation}`,
          badge: "Teacher",
          targetModule: "teachers",
          record: t,
        });
      }
    });

    // Filter Classes
    data.classes.forEach((c) => {
      const gName = stringValue(c.grade_name);
      const sName = stringValue(c.section_name ?? c.name);
      const classTitle = `${gName} - ${sName}`;
      const room = stringValue(c.room_number);

      if (!q || [gName, sName, classTitle, room].some((v) => v.toLowerCase().includes(q))) {
        matched.push({
          id: `c-${c.section_id || c.id}`,
          category: "class",
          title: classTitle,
          subtitle: `Room: ${room || "—"} · Capacity: ${stringValue(c.capacity || 30)}`,
          badge: "Class Section",
          targetModule: "classes",
          record: c,
        });
      }
    });

    // Filter Invoices (Principal)
    if (role === "principal") {
      data.invoices.forEach((inv) => {
        const invNum = stringValue(inv.invoice_number);
        const stName = displayName(nested(inv, "student"));

        if (!q || [invNum, stName].some((v) => v.toLowerCase().includes(q))) {
          matched.push({
            id: `inv-${inv.id}`,
            category: "invoice",
            title: invNum,
            subtitle: `Learner: ${stName} · Status: ${stringValue(inv.status)}`,
            badge: "Invoice",
            targetModule: "fees",
            record: inv,
          });
        }
      });
    }

    return matched.slice(0, 25);
  }, [query, navItems, data, role]);

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setSelectedIndex((prev) => (prev < results.length - 1 ? prev + 1 : 0));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSelectedIndex((prev) => (prev > 0 ? prev - 1 : results.length - 1));
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (results[selectedIndex]) {
        onSelectResult(results[selectedIndex]);
      }
    } else if (e.key === "Escape") {
      e.preventDefault();
      onClose();
    }
  }

  function renderCategoryIcon(category: SearchResultItem["category"]) {
    switch (category) {
      case "navigation": return <LayoutDashboard size={16} />;
      case "student": return <GraduationCap size={16} />;
      case "parent": return <HeartHandshake size={16} />;
      case "teacher": return <UserCog size={16} />;
      case "class": return <Building2 size={16} />;
      case "invoice": return <WalletCards size={16} />;
      default: return <Search size={16} />;
    }
  }

  return (
    <Dialog kicker="Spotlight search" title="" onClose={onClose}>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (results[selectedIndex]) onSelectResult(results[selectedIndex]);
        }}
        style={{ marginTop: "-0.5rem" }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: "0.6rem",
            padding: "0.6rem 0.8rem",
            background: "#f7fafc",
            border: "2px solid #2d70ae",
            borderRadius: "12px",
            boxShadow: "0 4px 12px rgba(0,0,0,0.06)",
          }}
        >
          <Search size={18} style={{ color: "#2d70ae" }} />
          <input
            ref={inputRef}
            type="text"
            className="search-input"
            placeholder="Search students, parents, teachers, classes, invoices, or jump to module… (Press Enter to select)"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            style={{
              border: "none",
              background: "transparent",
              outline: "none",
              boxShadow: "none",
              fontSize: "0.95rem",
              width: "100%",
            }}
          />
          {query && (
            <button
              type="button"
              className="icon-button"
              onClick={() => setQuery("")}
              title="Clear search"
            >
              <X size={14} />
            </button>
          )}
          <span
            style={{
              fontSize: "0.72rem",
              fontWeight: 700,
              padding: "0.2rem 0.4rem",
              background: "#e2edf7",
              color: "#164b78",
              borderRadius: "6px",
              whiteSpace: "nowrap",
            }}
          >
            ESC to close
          </span>
        </div>

        <div style={{ marginTop: "1rem", maxHeight: "380px", overflowY: "auto", paddingRight: "0.2rem" }}>
          {loading ? (
            <div className="skeleton-container" style={{ padding: "0.5rem" }}>
              <LoadingIndicator label="Searching school records…" />
              <div className="skeleton skeleton-row" />
              <div className="skeleton skeleton-row" />
            </div>
          ) : results.length > 0 ? (
            <div style={{ display: "grid", gap: "0.4rem" }}>
              {results.map((item, idx) => {
                const isSelected = idx === selectedIndex;
                return (
                  <div
                    key={item.id}
                    onClick={() => onSelectResult(item)}
                    onMouseEnter={() => setSelectedIndex(idx)}
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "0.8rem",
                      padding: "0.65rem 0.85rem",
                      borderRadius: "10px",
                      cursor: "pointer",
                      background: isSelected ? "#eef5fc" : "#fff",
                      border: isSelected ? "1px solid #b3d4f5" : "1px solid #eef3f6",
                      transition: "all 0.15s ease",
                    }}
                  >
                    <div
                      style={{
                        color: isSelected ? "#0c5496" : "#627888",
                        display: "inline-flex",
                        alignItems: "center",
                      }}
                    >
                      {renderCategoryIcon(item.category)}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <b style={{ display: "block", fontSize: "0.88rem", color: isSelected ? "#094175" : "#193c59" }}>
                        {item.title}
                      </b>
                      <small style={{ color: "#617785", fontSize: "0.76rem" }}>{item.subtitle}</small>
                    </div>
                    {item.badge && (
                      <span
                        className="status-pill"
                        style={{
                          background: isSelected ? "#d4e6f9" : "#f1f5f8",
                          color: isSelected ? "#083763" : "#516675",
                          fontSize: "0.72rem",
                        }}
                      >
                        {item.badge}
                      </span>
                    )}
                  </div>
                );
              })}
            </div>
          ) : (
            <p className="ops-empty" style={{ padding: "2rem 0" }}>
              No records or modules match &quot;{query}&quot;.
            </p>
          )}
        </div>
      </form>
    </Dialog>
  );
}

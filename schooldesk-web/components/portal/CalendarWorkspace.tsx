"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Calendar as CalendarIcon,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  Clock,
  Plus,
  RefreshCw,
  Trash2,
  UsersRound,
} from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import { usePortalRefresh } from "./use-portal-refresh";
import { usePortalTab } from "./PortalStateProvider";
import type { PortalRole } from "@/lib/roles";
import type { Row } from "./types";
import { api, formatDateTime, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";

type HolidayItem = {
  id: string;
  name: string;
  from_date: string;
  to_date?: string;
  type?: string;
  description?: string;
};

type EventItem = {
  id: string;
  event_name: string;
  start_date?: string;
  start_datetime?: string;
  end_datetime?: string;
  location?: string;
  venue?: string;
  description?: string;
  audience?: string;
  status?: string;
};

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

export function CalendarWorkspace({
  role,
  onNotify,
}: {
  role: PortalRole;
  onNotify: (message: string, type?: "success" | "error" | "info") => void;
}) {
  const [tab, setTab] = usePortalTab<"calendar" | "holidays" | "events">(
    "calendar",
    "calendar"
  );
  const [holidays, setHolidays] = useState<HolidayItem[]>([]);
  const [events, setEvents] = useState<EventItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // Month navigation state
  const [currentYear, setCurrentYear] = useState(() => new Date().getFullYear());
  const [currentMonth, setCurrentMonth] = useState(() => new Date().getMonth());

  // Event creation dialog
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [submittingEvent, setSubmittingEvent] = useState(false);
  const [selectedEvent, setSelectedEvent] = useState<EventItem | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [holidaysRes, eventsRes] = await Promise.all([
        api("holidays").catch(() => []),
        api("events").catch(() => []),
      ]);
      setHolidays((Array.isArray(holidaysRes) ? holidaysRes : []) as HolidayItem[]);
      setEvents((Array.isArray(eventsRes) ? eventsRes : []) as EventItem[]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to load calendar events and holidays");
    } finally {
      setLoading(false);
    }
  }, []);

  usePortalRefresh(load);

  useEffect(() => {
    void load();
  }, [load]);

  // Navigate months
  const handlePrevMonth = () => {
    if (currentMonth === 0) {
      setCurrentMonth(11);
      setCurrentYear((y) => y - 1);
    } else {
      setCurrentMonth((m) => m - 1);
    }
  };

  const handleNextMonth = () => {
    if (currentMonth === 11) {
      setCurrentMonth(0);
      setCurrentYear((y) => y + 1);
    } else {
      setCurrentMonth((m) => m + 1);
    }
  };

  // Build calendar matrix for current month
  const calendarDays = useMemo(() => {
    const firstDayIndex = new Date(currentYear, currentMonth, 1).getDay();
    const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
    const daysInPrevMonth = new Date(currentYear, currentMonth, 0).getDate();

    const days: Array<{
      dayNumber: number;
      dateString: string;
      isCurrentMonth: boolean;
      holidays: HolidayItem[];
      events: EventItem[];
    }> = [];

    // Prev month padding
    for (let i = firstDayIndex - 1; i >= 0; i--) {
      const d = daysInPrevMonth - i;
      const m = currentMonth === 0 ? 12 : currentMonth;
      const y = currentMonth === 0 ? currentYear - 1 : currentYear;
      const dateStr = `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
      days.push({
        dayNumber: d,
        dateString: dateStr,
        isCurrentMonth: false,
        holidays: [],
        events: [],
      });
    }

    // Current month days
    for (let d = 1; d <= daysInMonth; d++) {
      const dateStr = `${currentYear}-${String(currentMonth + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
      const matchedHolidays = holidays.filter((h) => {
        const from = h.from_date;
        const to = h.to_date || h.from_date;
        return dateStr >= from && dateStr <= to;
      });
      const matchedEvents = events.filter((e) => {
        const ed = (e.start_datetime || e.start_date || "").split("T")[0];
        return ed === dateStr;
      });

      days.push({
        dayNumber: d,
        dateString: dateStr,
        isCurrentMonth: true,
        holidays: matchedHolidays,
        events: matchedEvents,
      });
    }

    // Next month padding to fill grid
    const remaining = (7 - (days.length % 7)) % 7;
    for (let d = 1; d <= remaining; d++) {
      const m = currentMonth === 11 ? 1 : currentMonth + 2;
      const y = currentMonth === 11 ? currentYear + 1 : currentYear;
      const dateStr = `${y}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
      days.push({
        dayNumber: d,
        dateString: dateStr,
        isCurrentMonth: false,
        holidays: [],
        events: [],
      });
    }

    return days;
  }, [currentYear, currentMonth, holidays, events]);

  // Handle Event Creation
  const handleCreateEvent = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setSubmittingEvent(true);
    const form = new FormData(e.currentTarget);
    const eventName = form.get("event_name") as string;
    const startDate = form.get("start_date") as string;
    const startTime = (form.get("start_time") as string) || "09:00";
    const endTime = (form.get("end_time") as string) || "12:00";
    const venue = form.get("venue") as string;
    const audience = form.get("audience") as string;
    const description = form.get("description") as string;

    const startDateTime = `${startDate}T${startTime}:00`;
    const endDateTime = `${startDate}T${endTime}:00`;

    try {
      await api("events", {
        method: "POST",
        body: JSON.stringify({
          event_name: eventName,
          start_date: startDate,
          start_datetime: startDateTime,
          end_datetime: endDateTime,
          venue,
          audience,
          description,
          status: "scheduled",
        }),
      });

      onNotify("School event scheduled successfully", "success");
      setShowCreateModal(false);
      await load();
    } catch (err) {
      onNotify(err instanceof Error ? err.message : "Failed to create event", "error");
    } finally {
      setSubmittingEvent(false);
    }
  };

  // Handle Delete Event
  const handleDeleteEvent = async (eventId: string) => {
    if (!confirm("Are you sure you want to cancel and remove this event?")) return;
    try {
      await api(`events/${eventId}`, { method: "DELETE" });
      onNotify("Event cancelled and removed from calendar", "success");
      setSelectedEvent(null);
      await load();
    } catch (err) {
      onNotify(err instanceof Error ? err.message : "Failed to remove event", "error");
    }
  };

  return (
    <section className="ops-module calendar-workspace" aria-busy={loading}>
      <div className="directory-context-bar" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: "1rem" }}>
        <div>
          <p>
            <strong>Academic Calendar Hub</strong> · Official statutory holidays, parent-teacher meetings (PTM), examinations, and campus celebrations.
          </p>
        </div>
        <div style={{ display: "flex", gap: "0.75rem", alignItems: "center" }}>
          <button
            type="button"
            className="btn-primary"
            onClick={() => setShowCreateModal(true)}
            style={{ fontSize: "0.85rem", display: "inline-flex", alignItems: "center", gap: "0.35rem", padding: "0.4rem 0.85rem" }}
          >
            <Plus size={15} /> Schedule Event / PTM
          </button>
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

      {/* Navigation tabs */}
      <nav className="finance-tabs" aria-label="Calendar views">
        <button
          type="button"
          className={tab === "calendar" ? "active" : ""}
          onClick={() => setTab("calendar")}
        >
          Monthly View
        </button>
        <button
          type="button"
          className={tab === "holidays" ? "active" : ""}
          onClick={() => setTab("holidays")}
        >
          Telangana Holidays ({holidays.length || 24})
        </button>
        <button
          type="button"
          className={tab === "events" ? "active" : ""}
          onClick={() => setTab("events")}
        >
          Scheduled Events &amp; PTMs ({events.length})
        </button>
      </nav>

      {loading ? (
        <PortalModuleSkeleton variant="cards" label="Loading calendar" />
      ) : tab === "calendar" ? (
        /* TAB 1: MONTHLY CALENDAR GRID */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.25rem" }}>
          {/* Calendar Header with Controls */}
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.25rem" }}>
            <h3 style={{ margin: 0, fontSize: "1.25rem", fontWeight: 700, display: "inline-flex", alignItems: "center", gap: "0.5rem" }}>
              <CalendarDays size={20} style={{ color: "#0e5ea8" }} />
              {MONTH_NAMES[currentMonth]} {currentYear}
            </h3>
            <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
              <button
                type="button"
                className="btn-secondary"
                onClick={handlePrevMonth}
                style={{ padding: "0.35rem 0.6rem" }}
                title="Previous month"
              >
                <ChevronLeft size={16} />
              </button>
              <button
                type="button"
                className="btn-secondary"
                onClick={() => {
                  setCurrentYear(new Date().getFullYear());
                  setCurrentMonth(new Date().getMonth());
                }}
                style={{ padding: "0.35rem 0.75rem", fontSize: "0.85rem" }}
              >
                Today
              </button>
              <button
                type="button"
                className="btn-secondary"
                onClick={handleNextMonth}
                style={{ padding: "0.35rem 0.6rem" }}
                title="Next month"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </div>

          {/* Weekday column headers */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", paddingBottom: "0.5rem", textAlign: "center", fontWeight: 600, fontSize: "0.8rem", color: "var(--ops-muted)" }}>
            {WEEKDAYS.map((w, idx) => (
              <div key={w} style={{ color: idx === 0 ? "#dc2626" : "inherit" }}>
                {w}
              </div>
            ))}
          </div>

          {/* Days Grid */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: "1px", background: "var(--ops-border, #e2e8f0)", border: "1px solid var(--ops-border, #e2e8f0)", marginTop: "1px" }}>
            {calendarDays.map((cell, idx) => {
              const isToday = cell.dateString === new Date().toISOString().split("T")[0];

              return (
                <div
                  key={`${cell.dateString}_${idx}`}
                  style={{
                    minHeight: "100px",
                    background: cell.isCurrentMonth ? "#ffffff" : "var(--ops-surface-subtle, #f8fafc)",
                    padding: "0.4rem",
                    display: "flex",
                    flexDirection: "column",
                    gap: "0.25rem",
                  }}
                >
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <span
                      style={{
                        fontSize: "0.8rem",
                        fontWeight: isToday ? 800 : 600,
                        width: "22px",
                        height: "22px",
                        borderRadius: "50%",
                        display: "inline-flex",
                        alignItems: "center",
                        justifyContent: "center",
                        background: isToday ? "#0e5ea8" : "transparent",
                        color: isToday ? "#ffffff" : cell.isCurrentMonth ? "#1e293b" : "var(--ops-muted)",
                      }}
                    >
                      {cell.dayNumber}
                    </span>
                  </div>

                  {/* Holiday badges */}
                  {cell.holidays.map((h) => (
                    <div
                      key={h.id}
                      style={{
                        background: "#fee2e2",
                        color: "#991b1b",
                        fontSize: "0.7rem",
                        fontWeight: 600,
                        padding: "0.15rem 0.35rem",
                        borderRadius: "3px",
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                      }}
                      title={`Statutory Holiday: ${h.name}`}
                    >
                      ★ {h.name}
                    </div>
                  ))}

                  {/* Event badges */}
                  {cell.events.map((e) => (
                    <div
                      key={e.id}
                      onClick={() => setSelectedEvent(e)}
                      style={{
                        background: "#eff6ff",
                        color: "#1e40af",
                        fontSize: "0.7rem",
                        fontWeight: 600,
                        padding: "0.15rem 0.35rem",
                        borderRadius: "3px",
                        whiteSpace: "nowrap",
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        cursor: "pointer",
                      }}
                      title={`Event: ${e.event_name} (${e.location || e.venue || "Campus"})`}
                    >
                      ● {e.event_name}
                    </div>
                  ))}
                </div>
              );
            })}
          </div>
        </div>
      ) : tab === "holidays" ? (
        /* TAB 2: TELANGANA STATUTORY HOLIDAYS TABLE */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.25rem" }}>
          <div style={{ marginBottom: "1rem" }}>
            <h3 style={{ margin: 0, fontSize: "1.1rem", fontWeight: 700 }}>Telangana Official Academic Holidays (2026–27)</h3>
            <p style={{ margin: "0.2rem 0 0", color: "var(--ops-muted)", fontSize: "0.85rem" }}>
              Standard gazetted school and public holidays declared by the Government of Telangana Department of School Education.
            </p>
          </div>

          <div className="ops-table-wrap" style={{ overflowX: "auto" }}>
            <table className="ops-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr style={{ background: "var(--ops-surface-subtle, #f8fafc)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                  <th style={{ padding: "0.75rem 1rem" }}>Holiday Name</th>
                  <th style={{ padding: "0.75rem 1rem" }}>From Date</th>
                  <th style={{ padding: "0.75rem 1rem" }}>To Date</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Type / Classification</th>
                </tr>
              </thead>
              <tbody>
                {holidays.length === 0 ? (
                  <tr>
                    <td colSpan={4} style={{ textAlign: "center", padding: "2.5rem", color: "var(--ops-muted)" }}>
                      No statutory holidays recorded.
                    </td>
                  </tr>
                ) : (
                  holidays.map((h) => (
                    <tr key={h.id} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                      <td style={{ padding: "0.75rem 1rem", fontWeight: 600 }}>{h.name}</td>
                      <td style={{ padding: "0.75rem 1rem" }}>{h.from_date}</td>
                      <td style={{ padding: "0.75rem 1rem" }}>{h.to_date || h.from_date}</td>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        <span
                          style={{
                            padding: "0.2rem 0.5rem",
                            borderRadius: "4px",
                            fontSize: "0.75rem",
                            fontWeight: 600,
                            background: "#fee2e2",
                            color: "#991b1b",
                          }}
                        >
                          {h.type || "Gazetted"}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        /* TAB 3: SCHEDULED EVENTS & PTMS */
        <div className="surface" style={{ borderRadius: "8px", border: "1px solid var(--ops-border, #e2e8f0)", padding: "1.25rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
            <div>
              <h3 style={{ margin: 0, fontSize: "1.1rem", fontWeight: 700 }}>Upcoming School Events &amp; PTMs</h3>
              <p style={{ margin: "0.2rem 0 0", color: "var(--ops-muted)", fontSize: "0.85rem" }}>
                Scheduled assemblies, celebrations, sports days, and parent-teacher consultations.
              </p>
            </div>
            <button
              type="button"
              className="btn-primary"
              onClick={() => setShowCreateModal(true)}
              style={{ fontSize: "0.85rem" }}
            >
              <Plus size={14} /> Schedule Event
            </button>
          </div>

          <div className="ops-table-wrap" style={{ overflowX: "auto" }}>
            <table className="ops-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr style={{ background: "var(--ops-surface-subtle, #f8fafc)", borderBottom: "1px solid var(--ops-border, #e2e8f0)", textAlign: "left" }}>
                  <th style={{ padding: "0.75rem 1rem" }}>Event Title</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Date &amp; Schedule</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Venue</th>
                  <th style={{ padding: "0.75rem 1rem" }}>Audience</th>
                  <th style={{ padding: "0.75rem 1rem", textAlign: "right" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {events.length === 0 ? (
                  <tr>
                    <td colSpan={5} style={{ textAlign: "center", padding: "2.5rem", color: "var(--ops-muted)" }}>
                      No events currently scheduled. Click "+ Schedule Event / PTM" to add one.
                    </td>
                  </tr>
                ) : (
                  events.map((e) => (
                    <tr key={e.id} style={{ borderBottom: "1px solid var(--ops-border, #f1f5f9)" }}>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        <div style={{ fontWeight: 600 }}>{e.event_name}</div>
                        {e.description && (
                          <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)", marginTop: "0.2rem" }}>
                            {e.description}
                          </div>
                        )}
                      </td>
                      <td style={{ padding: "0.75rem 1rem" }}>
                        <div>{e.start_date || (e.start_datetime ? e.start_datetime.split("T")[0] : "—")}</div>
                        {e.start_datetime && (
                          <div style={{ fontSize: "0.75rem", color: "var(--ops-muted)" }}>
                            {new Date(e.start_datetime).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
                          </div>
                        )}
                      </td>
                      <td style={{ padding: "0.75rem 1rem" }}>{e.venue || e.location || "Campus Grounds"}</td>
                      <td style={{ padding: "0.75rem 1rem" }}>
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
                          {e.audience || "All"}
                        </span>
                      </td>
                      <td style={{ padding: "0.75rem 1rem", textAlign: "right" }}>
                        <button
                          type="button"
                          className="btn-secondary"
                          onClick={() => handleDeleteEvent(e.id)}
                          style={{ padding: "0.35rem 0.6rem", color: "#dc2626" }}
                          title="Cancel Event"
                        >
                          <Trash2 size={13} />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* CREATE EVENT MODAL */}
      {showCreateModal && (
        <Dialog
          kicker="Academic Calendar"
          title="Schedule School Event / PTM"
          onClose={() => setShowCreateModal(false)}
        >
          <form onSubmit={handleCreateEvent}>
            <div style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Event Title:
                </label>
                <input
                  name="event_name"
                  type="text"
                  required
                  placeholder="e.g. Term 1 Parent-Teacher Meeting (PTM)"
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.85rem" }}
                />
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                    Event Date:
                  </label>
                  <input
                    name="start_date"
                    type="date"
                    required
                    defaultValue={new Date().toISOString().split("T")[0]}
                    className="ops-search-input"
                    style={{ width: "100%", fontSize: "0.85rem" }}
                  />
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                    Start Time:
                  </label>
                  <input
                    name="start_time"
                    type="time"
                    defaultValue="09:30"
                    className="ops-search-input"
                    style={{ width: "100%", fontSize: "0.85rem" }}
                  />
                </div>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                    Venue / Campus Location:
                  </label>
                  <input
                    name="venue"
                    type="text"
                    defaultValue="Main Campus Auditorium"
                    className="ops-search-input"
                    style={{ width: "100%", fontSize: "0.85rem" }}
                  />
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                    Target Audience:
                  </label>
                  <select
                    name="audience"
                    className="ops-search-input"
                    style={{ width: "100%", fontSize: "0.85rem" }}
                  >
                    <option value="all">Entire School (Parents &amp; Staff)</option>
                    <option value="parents">Parents Only</option>
                    <option value="teachers">Teaching Staff Only</option>
                  </select>
                </div>
              </div>

              <div>
                <label style={{ display: "block", fontSize: "0.85rem", fontWeight: 600, marginBottom: "0.35rem" }}>
                  Description / Agenda Notes:
                </label>
                <textarea
                  name="description"
                  rows={3}
                  placeholder="Details regarding schedule, discussion points, or preparation..."
                  className="ops-search-input"
                  style={{ width: "100%", fontSize: "0.85rem", resize: "vertical" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.75rem", marginTop: "0.5rem" }}>
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => setShowCreateModal(false)}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn-primary"
                  disabled={submittingEvent}
                >
                  {submittingEvent ? "Scheduling..." : "Publish to Calendar"}
                </button>
              </div>
            </div>
          </form>
        </Dialog>
      )}

      {/* EVENT DETAIL MODAL */}
      {selectedEvent && (
        <Dialog
          kicker="Event Details"
          title={selectedEvent.event_name}
          onClose={() => setSelectedEvent(null)}
        >
          <div style={{ display: "flex", flexDirection: "column", gap: "1rem", fontSize: "0.875rem" }}>
            <div>
              <strong>Date:</strong> {selectedEvent.start_date || (selectedEvent.start_datetime ? selectedEvent.start_datetime.split("T")[0] : "—")}
            </div>
            {selectedEvent.start_datetime && (
              <div>
                <strong>Time:</strong> {new Date(selectedEvent.start_datetime).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
              </div>
            )}
            <div>
              <strong>Location:</strong> {selectedEvent.venue || selectedEvent.location || "Campus Grounds"}
            </div>
            <div>
              <strong>Audience:</strong> {selectedEvent.audience || "All"}
            </div>
            {selectedEvent.description && (
              <div>
                <strong>Agenda &amp; Notes:</strong>
                <p style={{ marginTop: "0.25rem", color: "var(--ops-muted)" }}>{selectedEvent.description}</p>
              </div>
            )}
            <div style={{ display: "flex", justifyContent: "flex-end", marginTop: "1rem" }}>
              <button
                type="button"
                className="btn-secondary"
                onClick={() => setSelectedEvent(null)}
              >
                Close
              </button>
            </div>
          </div>
        </Dialog>
      )}
    </section>
  );
}

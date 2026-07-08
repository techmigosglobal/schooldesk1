// handlers/sheets_pull.ts
// Pulls data from Google Sheets using the GOOGLE_SERVICE_ACCOUNT_JSON secret
// and syncs the Students + TimeTable sheets into the Supabase database.
//
// Endpoints (service-role auth required, POST):
//   /sheets/pull-students   body: { school_id, spreadsheet_id? }
//   /sheets/pull-timetable  body: { school_id, spreadsheet_id? }
//   /sheets/pull-all        body: { school_id, spreadsheet_id? }

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";
import { handleSheetsSyncStudent, handleSheetsSyncTimetable } from "./sheets_sync.ts";

// ── constants ────────────────────────────────────────────────
const DEFAULT_SPREADSHEET_ID = "1vXiPsxiwQY4CnvvfImpX_tFl5JEJRbr3pDeL6qY5zbg";
const STUDENTS_SHEET_NAME   = "Students";
const TIMETABLE_SHEET_NAME  = "TimeTable";

// ── JWT / OAuth helpers ──────────────────────────────────────

interface GoogleServiceAccount {
  client_email: string;
  private_key: string;
  [key: string]: unknown;
}

function base64url(data: Uint8Array): string {
  let binary = "";
  for (const byte of data) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function signJwt(
  sa: GoogleServiceAccount,
  claims: Record<string, unknown>,
): Promise<string> {
  const header  = base64url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const payload = base64url(new TextEncoder().encode(JSON.stringify(claims)));
  const unsigned = `${header}.${payload}`;
  const pemBody = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  return `${unsigned}.${base64url(new Uint8Array(sig))}`;
}

async function getGoogleAccessToken(sa: GoogleServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt(sa, {
    iss:   sa.client_email,
    scope: "https://www.googleapis.com/auth/spreadsheets.readonly",
    aud:   "https://oauth2.googleapis.com/token",
    exp:   now + 3600,
    iat:   now,
  });
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion:  jwt,
    }),
  });
  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Google OAuth failed: ${resp.status} - ${errText}`);
  }
  const data = await resp.json();
  return data.access_token as string;
}

// ── Sheets API helpers ───────────────────────────────────────

async function fetchSheetRows(
  token: string,
  spreadsheetId: string,
  sheetName: string,
): Promise<string[][]> {
  const range = encodeURIComponent(sheetName);
  const url   = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${range}`;
  const resp  = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(`Sheets API error for "${sheetName}": ${resp.status} - ${errText}`);
  }
  const data = await resp.json();
  return (data.values ?? []) as string[][];
}

function rowsToObjects(rows: string[][]): Record<string, string>[] {
  if (rows.length < 2) return [];
  const headers = rows[0].map((h) =>
    String(h ?? "").trim().toLowerCase().replace(/[\s\-]/g, "_"),
  );
  return rows.slice(1)
    .filter((row) => row.some((cell) => String(cell ?? "").trim() !== ""))
    .map((row) => {
      const obj: Record<string, string> = {};
      headers.forEach((header, i) => { obj[header] = String(row[i] ?? "").trim(); });
      return obj;
    });
}

function makeRequest(body: Record<string, unknown>): Request {
  return new Request("https://supabase.internal/sheets/internal", {
    method:  "POST",
    headers: { "Content-Type": "application/json" },
    body:    JSON.stringify(body),
  });
}

// ── Public handlers ──────────────────────────────────────────

export async function handleSheetsPullStudents(
  req: Request,
  svc: SupabaseClient,
): Promise<Response> {
  try {
    const body          = await req.json().catch(() => ({})) as Record<string, unknown>;
    const schoolId      = String(body.school_id ?? "").trim();
    const spreadsheetId = String(body.spreadsheet_id ?? DEFAULT_SPREADSHEET_ID).trim();
    if (!schoolId) return fail("school_id is required");

    const saJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
    if (!saJson) return fail("GOOGLE_SERVICE_ACCOUNT_JSON secret is not set");
    const sa: GoogleServiceAccount = JSON.parse(saJson);

    const token   = await getGoogleAccessToken(sa);
    const rows    = await fetchSheetRows(token, spreadsheetId, STUDENTS_SHEET_NAME);
    const records = rowsToObjects(rows);
    if (records.length === 0) return ok({ synced: 0, message: "No student rows found in sheet" });

    const results: Array<{ row: number; status: string; error?: string }> = [];
    for (let i = 0; i < records.length; i++) {
      const r = records[i];
      const payload: Record<string, unknown> = {
        school_id:         schoolId,
        student_id_number: r.student_id_number ?? r.student_id ?? r.id_number ?? r.roll_no ?? r.roll_number ?? "",
        first_name:        r.first_name ?? r.firstname ?? (r.name ?? "").split(" ")[0] ?? "",
        last_name:         r.last_name  ?? r.lastname  ?? (r.name ?? "").split(" ").slice(1).join(" ") ?? "",
        section_name:      r.section_name ?? r.class ?? r.section ?? r.grade ?? "",
        parent_username:   r.parent_username ?? r.parent_user ?? "",
        parent_name:       r.parent_name ?? r.parent ?? "",
        parent_email:      r.parent_email ?? "",
        parent_phone:      r.parent_phone ?? r.phone ?? "",
        date_of_birth:     r.date_of_birth ?? r.dob ?? "",
        gender:            r.gender ?? "",
        admission_date:    r.admission_date ?? "",
        status:            r.status ?? "active",
      };
      const res     = await handleSheetsSyncStudent(makeRequest(payload), svc);
      const resBody = await res.json();
      results.push({ row: i + 2, status: resBody.success ? "synced" : "error", error: resBody.success ? undefined : (resBody.error ?? "unknown") });
    }

    const synced = results.filter((r) => r.status === "synced").length;
    const errors = results.filter((r) => r.status === "error");
    return ok({ spreadsheet_id: spreadsheetId, sheet: STUDENTS_SHEET_NAME, total_rows: records.length, synced, errors: errors.length, error_details: errors.length > 0 ? errors : undefined });
  } catch (err) {
    return fail(`Pull students error: ${err instanceof Error ? err.message : String(err)}`);
  }
}

export async function handleSheetsPullTimetable(
  req: Request,
  svc: SupabaseClient,
): Promise<Response> {
  try {
    const body          = await req.json().catch(() => ({})) as Record<string, unknown>;
    const schoolId      = String(body.school_id ?? "").trim();
    const spreadsheetId = String(body.spreadsheet_id ?? DEFAULT_SPREADSHEET_ID).trim();
    if (!schoolId) return fail("school_id is required");

    const saJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
    if (!saJson) return fail("GOOGLE_SERVICE_ACCOUNT_JSON secret is not set");
    const sa: GoogleServiceAccount = JSON.parse(saJson);

    const token   = await getGoogleAccessToken(sa);
    const rows    = await fetchSheetRows(token, spreadsheetId, TIMETABLE_SHEET_NAME);
    const records = rowsToObjects(rows);
    if (records.length === 0) return ok({ synced: 0, message: "No timetable rows found in sheet" });

    const results: Array<{ row: number; status: string; error?: string }> = [];
    for (let i = 0; i < records.length; i++) {
      const r = records[i];
      const payload: Record<string, unknown> = {
        school_id:     schoolId,
        section_name:  r.section_name ?? r.class ?? r.section ?? "",
        day_of_week:   r.day_of_week  ?? r.day   ?? "",
        start_time:    r.start_time   ?? r.start  ?? "",
        end_time:      r.end_time     ?? r.end    ?? "",
        subject_name:  r.subject_name ?? r.subject ?? "",
        teacher_name:  r.teacher_name ?? r.teacher  ?? "",
        room_name:     r.room_name    ?? r.room     ?? "",
        period_number: r.period_number ?? r.period  ?? "",
        slot_type:     r.slot_type    ?? r.type     ?? "regular",
      };
      const res     = await handleSheetsSyncTimetable(makeRequest(payload), svc);
      const resBody = await res.json();
      results.push({ row: i + 2, status: resBody.success ? "synced" : "error", error: resBody.success ? undefined : (resBody.error ?? "unknown") });
    }

    const synced = results.filter((r) => r.status === "synced").length;
    const errors = results.filter((r) => r.status === "error");
    return ok({ spreadsheet_id: spreadsheetId, sheet: TIMETABLE_SHEET_NAME, total_rows: records.length, synced, errors: errors.length, error_details: errors.length > 0 ? errors : undefined });
  } catch (err) {
    return fail(`Pull timetable error: ${err instanceof Error ? err.message : String(err)}`);
  }
}

export async function handleSheetsPullAll(
  req: Request,
  svc: SupabaseClient,
): Promise<Response> {
  try {
    const body          = await req.json().catch(() => ({})) as Record<string, unknown>;
    const schoolId      = String(body.school_id ?? "").trim();
    const spreadsheetId = String(body.spreadsheet_id ?? DEFAULT_SPREADSHEET_ID).trim();
    if (!schoolId) return fail("school_id is required");

    const cloneReq = () => makeRequest({ school_id: schoolId, spreadsheet_id: spreadsheetId });
    const [studentsRes, timetableRes] = await Promise.all([
      handleSheetsPullStudents(cloneReq(), svc),
      handleSheetsPullTimetable(cloneReq(), svc),
    ]);
    const studentsData  = await studentsRes.json();
    const timetableData = await timetableRes.json();
    return ok({ students: studentsData.data ?? studentsData, timetable: timetableData.data ?? timetableData });
  } catch (err) {
    return fail(`Pull-all error: ${err instanceof Error ? err.message : String(err)}`);
  }
}

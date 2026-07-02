#!/usr/bin/env -S deno run --allow-net --allow-env --allow-write
/// <reference path="./deno-env.d.ts" />
// scripts/migrate_to_supabase.ts
// Migrates active data from Railway PostgreSQL to Supabase
// EXCLUDES: exams, exam_schedules, student_marks, grading_scales, report_cards,
//           report_exports, workflow_sessions, workflow_logs, assistant_*

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Config ────────────────────────────────────────────────────
const SOURCE_DB_URL = Deno.env.get("SOURCE_DATABASE_URL") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ARCHIVE_DIR = "./archive";
const TIMESTAMP = new Date().toISOString().replace(/[:.]/g, "-");

// Tables to MIGRATE (active schema)
const ACTIVE_TABLES = [
  "schools",
  "academic_years",
  "terms",
  "holidays",
  "working_day_configs",
  "departments",
  "subjects",
  "grades",
  "rooms",
  "sections",
  "grade_subjects",
  "roles",
  "permissions",
  "staff",
  "staff_qualifications",
  "staff_subjects",
  "staff_documents",
  "students",
  "guardians",
  "student_guardians",
  "medical_records",
  "student_documents",
  "enrollments",
  "parent_student_links",
  "transfer_records",
  "users",
  "user_sessions",
  "attendance_sessions",
  "student_attendances",
  "staff_attendances",
  "attendance_summaries",
  "substitutions",
  "fee_categories",
  "fee_structures",
  "fee_installments",
  "fee_invoices",
  "fee_invoice_items",
  "payments",
  "fee_receipts",
  "fee_concessions",
  "parent_payment_requests",
  "school_payment_settings",
  "leave_types",
  "leave_balances",
  "leave_applications",
  "student_leave_applications",
  "timetable_slots",
  "timetable_templates",
  "announcements",
  "event_posts",
  "message_conversations",
  "messages",
  "notification_logs",
  "notification_device_tokens",
  "diary_entries",
  "lesson_planners",
  "homework_submissions",
  "approval_requests",
  "account_approvals",
  "uploaded_files",
  "frontend_records",
  "bulk_import_jobs",
  "audit_logs",
  "error_events",
];

// Tables to ARCHIVE only (exam data, assistant, etc.)
const ARCHIVE_TABLES = [
  "exam_types",
  "exams",
  "exam_schedules",
  "student_marks",
  "grading_scales",
  "report_cards",
  "report_exports",
  "workflow_sessions",
  "workflow_logs",
];

// ── Helpers ───────────────────────────────────────────────────
async function querySource(sql: string): Promise<unknown[]> {
  // Uses PostgreSQL native connection via Deno's postgres driver
  const { Client } = await import("https://deno.land/x/postgres@v0.17.0/mod.ts");
  const client = new Client(SOURCE_DB_URL);
  await client.connect();
  const result = await client.queryArray(sql);
  await client.end();
  const [, ...rows] = result.rows as string[][];
  const cols = (result.rows[0] as string[]) ?? [];
  return rows.map((row) => Object.fromEntries(cols.map((c: string, i: number) => [c, row[i]])));
}

async function fetchTable(table: string): Promise<unknown[]> {
  const { Client } = await import("https://deno.land/x/postgres@v0.17.0/mod.ts");
  const client = new Client(SOURCE_DB_URL);
  await client.connect();
  try {
    const result = await client.queryObject(`SELECT * FROM "${table}"`);
    return result.rows ?? [];
  } catch (e: unknown) {
    console.warn(
      `  ⚠ Table "${table}" not found or error: ${e instanceof Error ? e.message : String(e)}`,
    );
    return [];
  } finally {
    await client.end();
  }
}

async function writeArchive(name: string, data: unknown[]) {
  await Deno.mkdir(ARCHIVE_DIR, { recursive: true });
  const file = `${ARCHIVE_DIR}/${name}_${TIMESTAMP}.json`;
  await Deno.writeTextFile(file, JSON.stringify(data, null, 2));
  console.log(`  📁 Archived ${data.length} rows → ${file}`);
}

// ── Main ──────────────────────────────────────────────────────
async function main() {
  if (!SOURCE_DB_URL || !SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.error("❌ Missing environment variables: SOURCE_DATABASE_URL, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY");
    Deno.exit(1);
  }

  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { persistSession: false },
  });

  console.log("\n══════════════════════════════════════════");
  console.log("  SchoolDesk → Supabase Data Migration");
  console.log(`  Source: ${SOURCE_DB_URL.replace(/:.*@/, ":***@")}`);
  console.log(`  Target: ${SUPABASE_URL}`);
  console.log("══════════════════════════════════════════\n");

  // ── Phase 1: Archive exam/assistant data ─────────────────
  console.log("📦 Archiving excluded tables (exams, results, etc.)...");
  for (const table of ARCHIVE_TABLES) {
    const rows = await fetchTable(table);
    if (rows.length > 0) await writeArchive(table, rows);
    else console.log(`  ℹ  "${table}" is empty, skipping archive`);
  }

  // ── Phase 2: Migrate active tables ───────────────────────
  console.log("\n🚀 Migrating active tables...");
  const results: Record<string, { source: number; inserted: number; errors: number }> = {};

  for (const table of ACTIVE_TABLES) {
    console.log(`  → ${table}...`);
    const rows = await fetchTable(table);
    if (rows.length === 0) {
      console.log(" empty");
      results[table] = { source: 0, inserted: 0, errors: 0 };
      continue;
    }

    // Strip max_marks / pass_marks from grade_subjects
    const cleaned = table === "grade_subjects"
      ? (rows as Record<string, unknown>[]).map((r) => {
          const { max_marks: _m, pass_marks: _p, ...rest } = r;
          return rest;
        })
      : rows;

    let inserted = 0;
    let errors = 0;

    // Batch insert in chunks of 500
    const CHUNK = 500;
    for (let i = 0; i < cleaned.length; i += CHUNK) {
      const chunk = (cleaned as unknown[]).slice(i, i + CHUNK);
      const { error } = await svc.from(table).upsert(chunk as Record<string, unknown>[], { onConflict: "id", ignoreDuplicates: true });
      if (error) {
        errors += chunk.length;
        console.warn(`\n    ⚠ Batch ${i / CHUNK + 1} error: ${error.message}`);
      } else {
        inserted += chunk.length;
      }
    }

    results[table] = { source: rows.length, inserted, errors };
    console.log(` ${rows.length} rows → ✓ ${inserted} / ✗ ${errors}`);
  }

  // ── Summary ───────────────────────────────────────────────
  console.log("\n══════════════════════════════════════════");
  console.log("  MIGRATION SUMMARY");
  console.log("══════════════════════════════════════════");

  let totalSrc = 0, totalOk = 0, totalErr = 0;
  for (const [t, r] of Object.entries(results)) {
    if (r.source > 0) console.log(`  ${t}: ${r.source} → ${r.inserted} ok, ${r.errors} errors`);
    totalSrc += r.source; totalOk += r.inserted; totalErr += r.errors;
  }

  console.log(`\n  Total: ${totalSrc} source rows, ${totalOk} migrated, ${totalErr} errors`);

  if (totalErr > 0) {
    console.error("\n❌ Migration completed with errors. Review logs above.");
    Deno.exit(1);
  } else {
    console.log("\n✅ Migration completed successfully!");
  }
}

main().catch((e) => { console.error(e); Deno.exit(1); });

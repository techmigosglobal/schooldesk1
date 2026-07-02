// handlers/medical.ts — parent health updates and medical records
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function sid(u: User) {
  return (u.app_metadata?.school_id as string) ?? "";
}

function role(u: User) {
  return `${u.app_metadata?.role_name ?? ""}`.trim().toLowerCase();
}

function text(value: unknown, fallback = ""): string {
  const valueText = `${value ?? ""}`.trim();
  return valueText || fallback;
}

async function parentCanAccessStudent(
  svc: SupabaseClient,
  user: User,
  studentId: string,
) {
  if (role(user) !== "parent") return true;
  if (!studentId) return false;
  const { data, error } = await svc.from("parent_student_links").select(
    "student_id",
  ).eq("parent_user_id", user.id).eq("student_id", studentId).maybeSingle();
  if (error) throw error;
  return Boolean(data);
}

function recordPayload(row: Record<string, unknown>) {
  return {
    ...row,
    medical_record_id: text(row.id),
    dosage: text(row.dosage),
    reminder_time: text(row.reminder_time),
    notes: text(row.notes),
    is_active: row.is_active ?? true,
  };
}

export async function handleMedical(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const body = method !== "GET"
    ? await req.json().catch(() => ({})) as Record<string, unknown>
    : {};

  if (path !== "/medical-records") return fail("not found", 404);

  if (method === "GET") {
    const studentId = text(url.searchParams.get("student_id"));
    if (studentId && !(await parentCanAccessStudent(svc, user, studentId))) {
      return fail("student not linked to parent", 403);
    }
    let query = svc.from("medical_records").select(
      "*, student:students(id, school_id, first_name, last_name)",
    );
    if (studentId) query = query.eq("student_id", studentId);
    const { data, error } = await query.order("updated_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const rows = (data ?? [])
      .filter((row: Record<string, unknown>) => {
        const student = row.student as Record<string, unknown> | null;
        return text(student?.school_id) === school;
      })
      .map((row: Record<string, unknown>) => recordPayload(row));
    return ok(rows);
  }

  if (method === "POST") {
    const studentId = text(body.student_id);
    if (!(await parentCanAccessStudent(svc, user, studentId))) {
      return fail("student not linked to parent", 403);
    }
    const { data, error } = await svc.from("medical_records").insert({
      student_id: studentId,
      blood_group: text(body.blood_group),
      allergies: text(body.allergies),
      conditions: text(body.conditions),
      medications: text(body.medications),
      emergency_contact: text(body.emergency_contact),
      dosage: text(body.dosage),
      reminder_time: text(body.reminder_time),
      notes: text(body.notes),
      is_active: body.is_active ?? true,
      updated_at: new Date().toISOString(),
    }).select("*").single();
    if (error) return fail(error.message);
    return ok(recordPayload(data as Record<string, unknown>));
  }

  return fail("method not allowed", 405);
}

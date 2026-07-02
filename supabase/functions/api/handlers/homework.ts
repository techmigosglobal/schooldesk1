// handlers/homework.ts — homework assignments, parent submissions, teacher review
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";

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

function payload(row: Record<string, unknown>): Record<string, unknown> {
  const data = row.data && typeof row.data === "object"
    ? row.data as Record<string, unknown>
    : row;
  return {
    ...data,
    id: text(data.id ?? row.record_id ?? row.id),
    homework_id: text(data.homework_id ?? data.id ?? row.record_id ?? row.id),
  };
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

async function studentSectionId(
  svc: SupabaseClient,
  school: string,
  studentId: string,
) {
  if (!studentId) return "";
  const { data, error } = await svc.from("students").select(
    "current_section_id",
  ).eq("id", studentId).eq("school_id", school).maybeSingle();
  if (error) throw error;
  return text(data?.current_section_id);
}

async function loadHomework(
  svc: SupabaseClient,
  school: string,
  homeworkId: string,
) {
  const { data, error } = await svc.from("frontend_records").select("*").eq(
    "school_id",
    school,
  ).eq("table_name", "homework").eq("record_id", homeworkId).maybeSingle();
  if (error) throw error;
  return data ? payload(data as Record<string, unknown>) : null;
}

function submissionPayload(row: Record<string, unknown>) {
  const urls = Array.isArray(row.file_urls) ? row.file_urls : [];
  return {
    ...row,
    attachment_urls: urls,
    attachment_url: text(urls[0]),
    answer_text: text(row.remarks),
    submitted_at: row.submitted_at ?? row.created_at,
  };
}

export async function handleHomework(
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

  if (path === "/homework") {
    if (method === "GET") {
      const studentId = text(url.searchParams.get("student_id"));
      if (studentId && !(await parentCanAccessStudent(svc, user, studentId))) {
        return fail("student not linked to parent", 403);
      }
      let query = svc.from("frontend_records").select("*", { count: "exact" })
        .eq("school_id", school).eq("table_name", "homework");
      const { data, error, count } = await query.order("updated_at", {
        ascending: false,
      });
      if (error) return fail(error.message);
      let rows = (data ?? []).map((row) =>
        payload(row as Record<string, unknown>)
      );
      const sectionId = text(url.searchParams.get("section_id"));
      const linkedSectionId = studentId
        ? await studentSectionId(svc, school, studentId)
        : "";
      const staffId = text(url.searchParams.get("staff_id"));
      const status = text(url.searchParams.get("status"));
      if (studentId) {
        rows = rows.filter((row) =>
          text(row.student_id) === studentId ||
          (text(row.student_id) === "" &&
            text(row.section_id) === linkedSectionId)
        );
      }
      if (sectionId) {
        rows = rows.filter((row) => text(row.section_id) === sectionId);
      }
      if (staffId) rows = rows.filter((row) => text(row.staff_id) === staffId);
      if (status) rows = rows.filter((row) => text(row.status) === status);
      return cors({
        success: true,
        data: rows,
        total: count ?? rows.length,
        page: 1,
        page_size: rows.length,
      });
    }

    if (method === "POST") {
      const id = crypto.randomUUID();
      const record = {
        ...body,
        id,
        homework_id: id,
        status: text(body.status, "pending"),
        assigned_date: body.assigned_date ?? new Date().toISOString(),
        due_date: body.due_date ?? body.submission_date ?? null,
        created_by: user.id,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      const { data, error } = await svc.from("frontend_records").insert({
        school_id: school,
        table_name: "homework",
        record_id: id,
        data: record,
      }).select().single();
      if (error) return fail(error.message);
      return ok(payload(data as Record<string, unknown>));
    }
  }

  const reminderPath = path === "/homework/reminders/today" ||
    path === "/homework/reminders/today/skip";
  if (reminderPath) {
    return ok({
      status: path.endsWith("/skip") ? "skipped" : "pending",
      section_id: text(url.searchParams.get("section_id") ?? body.section_id),
    });
  }

  const match = path.match(/^\/homework\/([^/]+)(?:\/(.*))?$/);
  if (!match) return fail("not found", 404);
  const homeworkId = match[1];
  const suffix = match[2] ?? "";

  if (!suffix && (method === "PUT" || method === "PATCH")) {
    const existing = await loadHomework(svc, school, homeworkId);
    if (!existing) return fail("not found", 404);
    const next = {
      ...existing,
      ...body,
      id: homeworkId,
      homework_id: homeworkId,
      updated_at: new Date().toISOString(),
    };
    const { data, error } = await svc.from("frontend_records").update({
      data: next,
      updated_at: new Date().toISOString(),
    }).eq("school_id", school).eq("table_name", "homework").eq(
      "record_id",
      homeworkId,
    ).select().single();
    if (error) return fail(error.message);
    return ok(payload(data as Record<string, unknown>));
  }

  if (!suffix && method === "DELETE") {
    await svc.from("homework_submissions").delete().eq("school_id", school).eq(
      "homework_id",
      homeworkId,
    );
    const { error } = await svc.from("frontend_records").delete().eq(
      "school_id",
      school,
    ).eq("table_name", "homework").eq("record_id", homeworkId);
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  if (suffix === "submissions" && method === "GET") {
    let query = svc.from("homework_submissions").select("*").eq(
      "school_id",
      school,
    ).eq("homework_id", homeworkId);
    const studentId = text(url.searchParams.get("student_id"));
    if (studentId) {
      if (!(await parentCanAccessStudent(svc, user, studentId))) {
        return fail("student not linked to parent", 403);
      }
      query = query.eq("student_id", studentId);
    }
    const { data, error } = await query.order("created_at", {
      ascending: false,
    });
    if (error) return fail(error.message);
    const submissions = (data ?? []).map((row) =>
      submissionPayload(row as Record<string, unknown>)
    );
    return ok({ submissions, total: submissions.length });
  }

  if (suffix === "submissions" && method === "POST") {
    const studentId = text(body.student_id);
    if (!(await parentCanAccessStudent(svc, user, studentId))) {
      return fail("student not linked to parent", 403);
    }
    const fileUrls = Array.isArray(body.attachment_urls)
      ? body.attachment_urls.map((value) => text(value)).filter(Boolean)
      : [];
    const attachmentUrl = text(body.attachment_url);
    if (attachmentUrl) fileUrls.unshift(attachmentUrl);
    const submission = {
      school_id: school,
      homework_id: homeworkId,
      student_id: studentId,
      submitted_at: new Date().toISOString(),
      file_urls: [...new Set(fileUrls)],
      remarks: text(body.answer_text),
      status: "submitted",
      updated_at: new Date().toISOString(),
    };
    const { data: existing, error: loadError } = await svc.from(
      "homework_submissions",
    ).select("id").eq("school_id", school).eq("homework_id", homeworkId).eq(
      "student_id",
      studentId,
    ).order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (loadError) return fail(loadError.message);
    const write = existing
      ? svc.from("homework_submissions").update(submission).eq(
        "id",
        existing.id,
      ).eq("school_id", school).select().single()
      : svc.from("homework_submissions").insert(submission).select().single();
    const { data, error } = await write;
    if (error) return fail(error.message);
    return ok(submissionPayload(data as Record<string, unknown>));
  }

  const reviewMatch = suffix.match(/^submissions\/([^/]+)\/review$/);
  if (reviewMatch && (method === "PUT" || method === "PATCH")) {
    const { data, error } = await svc.from("homework_submissions").update({
      status: text(body.status, "reviewed"),
      grade: text(body.grade),
      remarks: text(body.remarks),
      updated_at: new Date().toISOString(),
    }).eq("id", reviewMatch[1]).eq("school_id", school).eq(
      "homework_id",
      homeworkId,
    ).select().single();
    if (error) return fail(error.message);
    return ok(submissionPayload(data as Record<string, unknown>));
  }

  if (suffix === "attachment-requests" && method === "POST") {
    return ok({
      homework_id: homeworkId,
      student_id: text(body.student_id),
      status: "requested",
    });
  }

  return fail("not found", 404);
}

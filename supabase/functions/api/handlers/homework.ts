// handlers/homework.ts — homework assignments, parent submissions, teacher review
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok, triggerPushProcessing } from "../index.ts";

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

// Resolves the authenticated account for the staff member who assigned the
// homework. Older staff rows did not always persist linked_type, so linked_id
// is the stable relationship; the ID lookup also covers legacy imports where
// the staff and user IDs are the same.
async function teacherUserIdForStaff(
  svc: SupabaseClient,
  school: string,
  staffId: string,
) {
  if (!staffId) return "";
  const { data: linked } = await svc.from("users").select("id")
    .eq("school_id", school).eq("linked_id", staffId).limit(1).maybeSingle();
  if (text(linked?.id)) return text(linked?.id);
  const { data: direct } = await svc.from("users").select("id")
    .eq("school_id", school).eq("id", staffId).limit(1).maybeSingle();
  return text(direct?.id);
}

async function studentNameForId(
  svc: SupabaseClient,
  school: string,
  studentId: string,
) {
  if (!studentId) return "Student";
  const { data } = await svc.from("students").select("first_name, last_name")
    .eq("school_id", school).eq("id", studentId).maybeSingle();
  const name = `${text(data?.first_name)} ${text(data?.last_name)}`.trim();
  return name || "Student";
}

function submissionPayload(row: Record<string, unknown>) {
  const urls = Array.isArray(row.file_urls) ? row.file_urls : [];
  // `remarks` was the legacy shared field. Keep it as a fallback for older
  // rows, but expose the two authors' messages separately from now on.
  const parentComment = text(row.parent_comment) || text(row.remarks);
  return {
    ...row,
    attachment_urls: urls,
    attachment_url: text(urls[0]),
    parent_comment: parentComment,
    teacher_feedback: text(row.teacher_feedback),
    answer_text: parentComment,
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

      // Resolve teacher UUIDs to names
      const staffIds = [
        ...new Set(rows.map((row) => text(row.staff_id)).filter(Boolean)),
      ];
      if (staffIds.length > 0) {
        const { data: staffMembers } = await svc.from("staff")
          .select("id, first_name, last_name")
          .in("id", staffIds);

        if (staffMembers) {
          const staffNameMap = new Map(
            staffMembers.map((s) => [
              text(s.id),
              `${text(s.first_name)} ${text(s.last_name)}`.trim(),
            ]),
          );
          rows = rows.map((row) => {
            const name = staffNameMap.get(text(row.staff_id));
            return {
              ...row,
              teacher_name: name || text(row.staff_id),
              created_by_name: name || text(row.staff_id),
            };
          });
        }
      }

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

      // Notify the linked parent for every assigned child.  A teacher can
      // target one student or a whole section; both paths need the same
      // in-app and push notification contract.
      const sectionId = text(body.section_id);
      const assignedStudentIds = new Set<string>();
      const individualStudentId = text(body.student_id);
      if (individualStudentId) assignedStudentIds.add(individualStudentId);
      if (sectionId) {
        const { data: students } = await svc.from("students")
          .select("id")
          .eq("school_id", school)
          .eq("current_section_id", sectionId);
        for (const student of students ?? []) {
          const studentId = text(student.id);
          if (studentId) assignedStudentIds.add(studentId);
        }
      }

      if (assignedStudentIds.size > 0) {
        const { data: links } = await svc.from("parent_student_links")
          .select("parent_user_id, student_id")
          .eq("school_id", school)
          .in("student_id", [...assignedStudentIds]);

        if (links && links.length > 0) {
          const notifications = links.map(
            (link: { parent_user_id: string; student_id: string }) => ({
              school_id: school,
              user_id: link.parent_user_id,
              target_role: "parent",
              title: `New Homework: ${text(body.title, "Assignment")}`,
              body: `Homework assigned for ${
                text(body.subject_id, "your child's class")
              }.`,
              type: "homework",
              entity_type: "homework",
              entity_id: id,
              is_read: false,
              route: "/parent-homework-screen/submit",
              student_id: link.student_id,
            }),
          );
          // Insert in-app notification logs.
          const { error: notificationError } = await svc.from(
            "notification_logs",
          ).insert(notifications);
          if (notificationError) {
            console.error(
              "Failed to write homework in-app notifications",
              notificationError.message,
            );
          }
          // Also queue FCM pushes for the same linked parents.
          try {
            const hwTitle = text(body.title, "Assignment");
            const subjectLabel = text(
              body.subject_id,
              "your child's class",
            );
            const eventRows = links.map(
              (link: { parent_user_id: string; student_id: string }) => ({
                school_id: school,
                user_id: link.parent_user_id,
                event_type: "homework_assigned",
                event_data: {
                  homework_id: id,
                  title: `New Homework: ${hwTitle}`,
                  message: `Homework assigned for ${subjectLabel}.`,
                  reference_type: "homework",
                  reference_id: id,
                  action: "assignment",
                  route: "/parent-homework-screen/submit",
                  student_id: link.student_id,
                },
              }),
            );
            const { data: events, error: eventError } = await svc
              .from("notification_events")
              .insert(eventRows)
              .select("id");
            if (!eventError) {
              const eventIds = (events ?? []).map((row: { id: string }) =>
                text(row.id)
              ).filter(Boolean);
              if (eventIds.length > 0) triggerPushProcessing(eventIds);
            }
          } catch (_) {
            /* best-effort push — notification_logs already saved */
          }
        }
      }

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
    let query = svc.from("homework_submissions").select(
      "*, students (first_name, last_name)",
    ).eq(
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
    const submissions = (data ?? []).map((row) => {
      const studentObj = row.students as Record<string, unknown> | null;
      const firstName = studentObj ? text(studentObj.first_name) : "";
      const lastName = studentObj ? text(studentObj.last_name) : "";
      const fullName = `${firstName} ${lastName}`.trim();
      return {
        ...submissionPayload(row as Record<string, unknown>),
        student_name: fullName || text(row.student_id),
      };
    });
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
      // Preserve the parent's submission comment when a teacher later adds
      // feedback. `remarks` remains populated only for legacy consumers.
      parent_comment: text(body.answer_text),
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
    if (error) return fail(error.message); // Notify the teacher who assigned this homework
    const hw = await loadHomework(svc, school, homeworkId);
    if (hw) {
      const staffId = text(hw.staff_id ?? hw.teacher_id);
      const hwTitle = text(hw.title, "Homework");
      const hasAttachment = fileUrls.length > 0;
      const studentName = await studentNameForId(svc, school, studentId);
      const notifBody = `${studentName} submitted${
        hasAttachment ? " (with attachment)" : ""
      }: ${hwTitle}`;

      const teacherUserId = await teacherUserIdForStaff(svc, school, staffId) ||
        text(hw.created_by);

      const notifBase = {
        school_id: school,
        target_role: "teacher",
        title: `Homework Submitted: ${hwTitle}`,
        body: notifBody,
        type: "homework",
        entity_type: "homework",
        entity_id: text((data as Record<string, unknown>).id),
        is_read: false,
        route: "/teacher-homework-screen/submissions",
        student_id: studentId,
        teacher_id: staffId,
      };
      if (teacherUserId) {
        const { error: notificationError } = await svc.from(
          "notification_logs",
        ).insert({
          ...notifBase,
          user_id: teacherUserId,
        });
        if (notificationError) {
          console.error(
            "Failed to write homework submission in-app notification",
            notificationError.message,
          );
        }
        // Create push notification event for the teacher
        try {
          const { data: eventRow } = await svc.from("notification_events")
            .insert({
              school_id: school,
              user_id: teacherUserId,
              event_type: "homework_submitted",
              event_data: {
                homework_id: homeworkId,
                title: `Homework Submitted: ${hwTitle}`,
                message: notifBody,
                reference_type: "homework",
                reference_id: text((data as Record<string, unknown>).id),
                action: "submission",
                route: "/teacher-homework-screen/submissions",
                student_id: studentId,
                teacher_id: staffId,
              },
            }).select("id").maybeSingle();
          if (eventRow?.id) triggerPushProcessing(eventRow.id);
        } catch (_) { /* best-effort */ }
      }
    }

    return ok(submissionPayload(data as Record<string, unknown>));
  }

  const reviewMatch = suffix.match(/^submissions\/([^/]+)\/review$/);
  if (reviewMatch && (method === "PUT" || method === "PATCH")) {
    const reviewStatus = text(body.status, "reviewed");
    const reviewRemarks = text(body.remarks);
    const { data, error } = await svc.from("homework_submissions").update({
      status: reviewStatus,
      grade: text(body.grade),
      teacher_feedback: reviewRemarks,
      updated_at: new Date().toISOString(),
    }).eq("id", reviewMatch[1]).eq("school_id", school).eq(
      "homework_id",
      homeworkId,
    ).select().single();
    if (error) return fail(error.message);

    // Notify the parent of the reviewed student
    const submissionRow = data as Record<string, unknown>;
    const studentId = text(submissionRow.student_id);
    const hw = await loadHomework(svc, school, homeworkId);
    const hwTitle = text(hw?.title, "Homework");
    if (studentId) {
      const { data: linkRows } = await svc.from("parent_student_links")
        .select("parent_user_id")
        .eq("student_id", studentId);
      if (linkRows && linkRows.length > 0) {
        const feedbackTitle = reviewStatus === "reviewed"
          ? `Homework Approved: ${hwTitle}`
          : `Homework Needs Revision: ${hwTitle}`;
        const feedbackBody = reviewRemarks.length > 0
          ? reviewRemarks
          : (reviewStatus === "reviewed"
            ? "Your child's homework has been approved by the teacher."
            : "Your child's homework needs revision. Please check the feedback.");
        const parentNotifs = linkRows.map((l: { parent_user_id: string }) => ({
          school_id: school,
          user_id: l.parent_user_id,
          target_role: "parent",
          title: feedbackTitle,
          body: feedbackBody,
          type: "homework",
          entity_type: "homework",
          entity_id: homeworkId,
          is_read: false,
          route: "/parent-homework-screen/submit",
          student_id: studentId,
        }));
        const { error: notificationError } = await svc.from(
          "notification_logs",
        ).insert(parentNotifs);
        if (notificationError) {
          console.error(
            "Failed to write homework feedback in-app notification",
            notificationError.message,
          );
        }
        // Create push notification events for each parent
        try {
          const eventIds: string[] = [];
          for (const l of linkRows) {
            const { data: eventRow } = await svc.from("notification_events")
              .insert({
                school_id: school,
                user_id: l.parent_user_id,
                event_type: "homework_feedback",
                event_data: {
                  homework_id: homeworkId,
                  message: feedbackBody,
                  reference_type: "homework",
                },
              }).select("id").maybeSingle();
            if (eventRow?.id) eventIds.push(eventRow.id);
          }
          triggerPushProcessing(eventIds);
        } catch (_) { /* best-effort */ }
      }
    }

    return ok(submissionPayload(submissionRow));
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

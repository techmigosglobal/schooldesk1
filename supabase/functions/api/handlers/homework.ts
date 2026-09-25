// handlers/homework.ts — homework assignments, parent submissions, teacher review
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok, triggerPushProcessing } from "../index.ts";
import {
  claimDailyOperation,
  DailyClaimConflict,
  loadDailyClaim,
  sectionAcademicYear,
  teacherCanUseSection,
  todayDate,
  wasDailyClaimCreatedByThisRequest,
} from "./daily_claims.ts";
import {
  resolveActiveTeacherScope,
  teacherCanUseSubject,
} from "./teacher_scope.ts";
import {
  homeworkOperationDate,
  isIsoDate,
  isUuid,
} from "../lib/homework_legacy.ts";
import { signedPrivateFileUrl, stableStorageReference } from "../storage_helpers.ts";

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
  school: string,
  studentId: string,
) {
  if (role(user) !== "parent") return false;
  if (!studentId) return false;
  const { data, error } = await svc.from("parent_student_links").select(
    "student_id",
  ).eq("school_id", school).eq("parent_user_id", user.id).eq(
    "student_id",
    studentId,
  ).maybeSingle();
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

async function studentBelongsToSection(
  svc: SupabaseClient,
  school: string,
  studentId: string,
  sectionId: string,
): Promise<boolean> {
  if (!studentId || !sectionId) return false;
  const { data, error } = await svc.from("students").select("id").eq(
    "school_id",
    school,
  ).eq("id", studentId).eq("current_section_id", sectionId).maybeSingle();
  if (error) throw new Error(error.message);
  return Boolean(data?.id);
}

function isSchoolLeader(user: User): boolean {
  return ["admin", "principal", "coordinator", "super_admin"].includes(
    role(user),
  );
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

async function homeworkAcademicYearId(
  svc: SupabaseClient,
  school: string,
  homework: Record<string, unknown>,
): Promise<string> {
  const sectionId = text(homework.section_id);
  if (!isUuid(sectionId)) return "";

  const storedYearId = text(homework.academic_year_id);
  // A valid stored year is checked against the section. Missing or malformed
  // legacy values are resolved from the section's authoritative year.
  return sectionAcademicYear(
    svc,
    school,
    sectionId,
    isUuid(storedYearId) ? storedYearId : "",
  );
}

async function loadHomeworkDailyClaim(
  svc: SupabaseClient,
  school: string,
  homework: Record<string, unknown>,
) {
  const sectionId = text(homework.section_id);
  const operationDate = homeworkOperationDate(homework);
  if (!isUuid(sectionId) || !isIsoDate(operationDate)) return null;
  const academicYearId = await homeworkAcademicYearId(svc, school, homework);
  if (!isUuid(academicYearId)) return null;
  return loadDailyClaim(
    svc,
    school,
    academicYearId,
    sectionId,
    "homework",
    operationDate,
  );
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

async function materializeHomeworkAttachments(
  svc: SupabaseClient,
  row: Record<string, unknown>,
) {
  const raw = Array.isArray(row.attachment_urls)
    ? row.attachment_urls
    : Array.isArray(row.file_urls)
    ? row.file_urls
    : text(row.attachment_url)
    ? [row.attachment_url]
    : [];
  const urls = await Promise.all(raw.map(async (value) => {
    const stable = stableStorageReference(value);
    return await signedPrivateFileUrl(svc, stable) || text(value);
  }));
  return {
    ...row,
    attachment_urls: urls,
    attachment_url: text(urls[0]),
    file_urls: Array.isArray(row.file_urls) ? urls : row.file_urls,
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
      const requestedSectionId = text(url.searchParams.get("section_id"));
      const requestedStaffId = text(url.searchParams.get("staff_id"));
      const requestedStatus = text(url.searchParams.get("status"));
      const page = Math.max(
        parseInt(url.searchParams.get("page") ?? "1") || 1,
        1,
      );
      const pageSize = Math.min(
        Math.max(parseInt(url.searchParams.get("page_size") ?? "20") || 20, 1),
        100,
      );
      if (
        studentId && role(user) === "parent" &&
        !(await parentCanAccessStudent(svc, user, school, studentId))
      ) {
        return fail("student not linked to parent", 403);
      }
      let query = svc.from("frontend_records").select("*", { count: "exact" })
        .eq("school_id", school).eq("table_name", "homework");
      // These JSONB predicates keep common filters in the database. Teacher
      // assignment scope still gets a second authoritative check below.
      if (requestedSectionId) {
        query = query.eq("data->>section_id", requestedSectionId);
      }
      if (requestedStaffId && role(user) !== "teacher") {
        query = query.eq("data->>staff_id", requestedStaffId);
      }
      if (requestedStatus) {
        query = query.eq("data->>status", requestedStatus);
      }
      const { data, error } = await query.order("updated_at", {
        ascending: false,
      });
      if (error) return fail(error.message);
      let rows = (data ?? []).map((row) =>
        payload(row as Record<string, unknown>)
      );

      if (role(user) === "teacher") {
        const linkedStaffId = text(user.app_metadata?.linked_id);
        const sectionId = requestedSectionId;
        const scope = await resolveActiveTeacherScope(
          svc,
          school,
          linkedStaffId,
        );
        const allowedSections = new Set(scope.sections.keys());
        if (sectionId && !allowedSections.has(sectionId)) {
          return fail("forbidden", 403);
        }
        rows = rows.filter((row) => {
          const rowSection = text(row.section_id);
          const assignment = scope.sections.get(rowSection);
          if (!assignment) return false;
          return assignment.isClassTeacher || assignment.isCoTeacher ||
            assignment.subjectIds.has(text(row.subject_id));
        });
      }

      if (role(user) === "parent") {
        const { data: links, error: linksError } = await svc.from(
          "parent_student_links",
        ).select("student_id, student:students(current_section_id)").eq(
          "school_id",
          school,
        ).eq("parent_user_id", user.id);
        if (linksError) return fail(linksError.message);
        const studentIds = new Set(
          (links ?? []).map((link) => text(link.student_id))
            .filter(Boolean),
        );
        const sectionIds = new Set(
          (links ?? []).map((link: any) =>
            text(link.student?.current_section_id)
          ).filter(Boolean),
        );
        rows = rows.filter((row) => {
          const rowStudentId = text(row.student_id);
          return rowStudentId
            ? studentIds.has(rowStudentId)
            : sectionIds.has(text(row.section_id));
        });
      }

      const linkedSectionId = studentId
        ? await studentSectionId(svc, school, studentId)
        : "";
      if (studentId) {
        rows = rows.filter((row) =>
          text(row.student_id) === studentId ||
          (text(row.student_id) === "" &&
            text(row.section_id) === linkedSectionId)
        );
      }
      if (requestedSectionId) {
        rows = rows.filter((row) =>
          text(row.section_id) === requestedSectionId
        );
      }
      if (requestedStaffId && role(user) !== "teacher") {
        rows = rows.filter((row) => text(row.staff_id) === requestedStaffId);
      }
      if (requestedStatus) {
        rows = rows.filter((row) => text(row.status) === requestedStatus);
      }
      const total = rows.length;
      const pageRows = rows.slice((page - 1) * pageSize, page * pageSize);
      const staffIds = [
        ...new Set(pageRows.map((row) => text(row.staff_id)).filter(Boolean)),
      ];
      if (staffIds.length > 0) {
        const { data: staffMembers } = await svc.from("staff")
          .select("id, first_name, last_name")
          .in("id", staffIds);
        const staffNameMap = new Map(
          (staffMembers ?? []).map((s) => [
            text(s.id),
            `${text(s.first_name)} ${text(s.last_name)}`.trim(),
          ]),
        );
        for (const row of pageRows) {
          const name = staffNameMap.get(text(row.staff_id));
          if (name) {
            row.teacher_name = name;
            row.created_by_name = name;
          }
        }
      }
      const listRows = await Promise.all(pageRows.map(async (row) => {
        const {
          attachment_url: _attachmentUrl,
          attachment_urls: _attachmentUrls,
          file_urls: _fileUrls,
          attachments: _attachments,
          ...lightweight
        } = row;
        return {
          ...lightweight,
        daily_claim: await loadHomeworkDailyClaim(svc, school, row),
        };
      }));
      return cors({
        success: true,
        data: listRows,
        total,
        page,
        page_size: pageSize,
        has_more: page * pageSize < total,
      });
    }

    if (method === "POST") {
      const teacher = role(user) === "teacher";
      const linkedStaffId = text(user.app_metadata?.linked_id);
      const sectionId = text(body.section_id);
      if (teacher) {
        if (!linkedStaffId) return fail("staff profile not linked", 400);
        if (
          !sectionId ||
          !await teacherCanUseSection(svc, school, linkedStaffId, sectionId)
        ) {
          return fail("forbidden", 403);
        }
        if (
          !await teacherCanUseSubject(
            svc,
            school,
            linkedStaffId,
            sectionId,
            text(body.subject_id),
          )
        ) return fail("teacher is not assigned to this subject", 403);
        if (text(body.staff_id) && text(body.staff_id) !== linkedStaffId) {
          return fail("forbidden", 403);
        }
        const studentId = text(body.student_id);
        if (
          studentId && !await studentBelongsToSection(
            svc,
            school,
            studentId,
            sectionId,
          )
        ) return fail("student does not belong to the selected section", 422);
      }
      const academicYearId = sectionId
        ? await sectionAcademicYear(
          svc,
          school,
          sectionId,
          text(body.academic_year_id),
        )
        : "";
      if (teacher && !academicYearId) {
        return fail("section and academic year do not match", 422);
      }
      const operationDate =
        text(body.assigned_date || todayDate()).split("T")[0];
      let claim: Record<string, unknown> | null = null;
      if (teacher) {
        try {
          claim = await claimDailyOperation({
            svc,
            school,
            sectionId,
            academicYearId,
            operation: "homework",
            operationDate,
            staffId: linkedStaffId,
          });
        } catch (error) {
          if (error instanceof DailyClaimConflict) {
            return cors({
              success: false,
              error: "homework is already claimed by another teacher",
              daily_claim: error.claim,
            }, 409);
          }
          return fail(
            error instanceof Error ? error.message : "failed to claim homework",
            409,
          );
        }
      }
      const id = crypto.randomUUID();
      const record = {
        ...body,
        attachment_url: stableStorageReference(body.attachment_url),
        attachment_urls: Array.isArray(body.attachment_urls)
          ? body.attachment_urls.map(stableStorageReference)
          : body.attachment_urls,
        id,
        homework_id: id,
        status: text(body.status, "pending"),
        due_date: body.due_date ?? body.submission_date ?? null,
        created_by: user.id,
        staff_id: teacher ? linkedStaffId : text(body.staff_id),
        academic_year_id: academicYearId || text(body.academic_year_id),
        assigned_date: operationDate,
        daily_claim_id: claim?.id ?? null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      const { data, error } = await svc.from("frontend_records").insert({
        school_id: school,
        table_name: "homework",
        record_id: id,
        data: record,
      }).select().single();
      if (error) {
        if (claim && wasDailyClaimCreatedByThisRequest(claim)) {
          await svc.from("class_daily_operation_claims").delete().eq(
            "id",
            claim.id,
          )
            .eq("school_id", school).eq("claimed_by_staff_id", linkedStaffId);
        }
        return fail(error.message);
      }

      // Notify the linked parent for every assigned child.  A teacher can
      // target one student or a whole section; both paths need the same
      // in-app and push notification contract.
      const assignedStudentIds = new Set<string>();
      const individualStudentId = text(body.student_id);
      if (individualStudentId) assignedStudentIds.add(individualStudentId);
      if (sectionId) {
        const { data: students } = await svc.from("students")
          .select("id")
          .eq("school_id", school)
          .eq("current_section_id", sectionId)
          .eq("status", "active");
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
              title: `New Dairy: ${text(body.title, "Assignment")}`,
              body: `Dairy assigned for ${
                text(body.subject_id, "your child's class")
              }.`,
              type: "homework",
              entity_type: "homework",
              entity_id: id,
              is_read: false,
              priority: "high",
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
                  title: `New Dairy: ${hwTitle}`,
                  message: `Dairy assigned for ${subjectLabel}.`,
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

      return ok({
        ...(await materializeHomeworkAttachments(
          svc,
          payload(data as Record<string, unknown>),
        )),
        daily_claim: claim,
      });
    }
  }

  const reminderPath = path === "/homework/reminders/today" ||
    path === "/homework/reminders/today/skip";
  if (reminderPath) {
    const sectionId = text(
      url.searchParams.get("section_id") ?? body.section_id,
    );
    if (
      role(user) === "teacher" &&
      (!text(user.app_metadata?.linked_id) || !sectionId ||
        !await teacherCanUseSection(
          svc,
          school,
          text(user.app_metadata?.linked_id),
          sectionId,
        ))
    ) return fail("forbidden", 403);
    return ok({
      status: path.endsWith("/skip") ? "skipped" : "pending",
      section_id: sectionId,
    });
  }

  const match = path.match(/^\/homework\/([^/]+)(?:\/(.*))?$/);
  if (!match) return fail("not found", 404);
  const homeworkId = match[1];
  const suffix = match[2] ?? "";

  if (!suffix && (method === "PUT" || method === "PATCH")) {
    const existing = await loadHomework(svc, school, homeworkId);
    if (!existing) return fail("not found", 404);
    if (role(user) === "teacher") {
      const linkedStaffId = text(user.app_metadata?.linked_id);
      const sectionId = text(existing.section_id);
      if (
        !linkedStaffId || !sectionId ||
        !await teacherCanUseSection(svc, school, linkedStaffId, sectionId)
      ) {
        return fail("forbidden", 403);
      }
      if (
        !await teacherCanUseSubject(
          svc,
          school,
          linkedStaffId,
          sectionId,
          text(body.subject_id ?? existing.subject_id),
        )
      ) return fail("teacher is not assigned to this subject", 403);
      const operationDate = homeworkOperationDate(existing);
      const academicYearId = await homeworkAcademicYearId(
        svc,
        school,
        existing,
      );
      if (!isUuid(academicYearId) || !isIsoDate(operationDate)) {
        return fail(
          "section, academic year, and assigned date are required",
          422,
        );
      }
      try {
        const claim = await claimDailyOperation({
          svc,
          school,
          sectionId,
          academicYearId,
          operation: "homework",
          operationDate,
          staffId: linkedStaffId,
        });
        if (text(claim.claimed_by_staff_id) !== linkedStaffId) {
          return fail("homework is claimed by another teacher", 409);
        }
      } catch (error) {
        if (error instanceof DailyClaimConflict) {
          return cors({
            success: false,
            error: error.message,
            daily_claim: error.claim,
          }, 409);
        }
        return fail(
          error instanceof Error ? error.message : "failed to claim homework",
          409,
        );
      }
    }
    const teacherMutableBody = role(user) === "teacher"
      ? Object.fromEntries(
        Object.entries(body).filter(([key]) =>
          ![
            "id",
            "homework_id",
            "school_id",
            "staff_id",
            "teacher_id",
            "section_id",
            "academic_year_id",
            "assigned_date",
            "daily_claim_id",
            "student_id",
            "created_by",
            "created_at",
          ].includes(key)
        ),
      )
      : body;
    const next = {
      ...existing,
      ...teacherMutableBody,
      attachment_url: stableStorageReference(
        (teacherMutableBody as Record<string, unknown>).attachment_url ??
          existing.attachment_url,
      ),
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
    return ok(
      await materializeHomeworkAttachments(
        svc,
        payload(data as Record<string, unknown>),
      ),
    );
  }

  if (!suffix && method === "DELETE") {
    if (role(user) === "teacher") {
      const existing = await loadHomework(svc, school, homeworkId);
      if (!existing) return fail("not found", 404);
      const linkedStaffId = text(user.app_metadata?.linked_id);
      const sectionId = text(existing.section_id);
      if (
        !linkedStaffId || !sectionId ||
        text(existing.staff_id) !== linkedStaffId ||
        !await teacherCanUseSection(svc, school, linkedStaffId, sectionId)
      ) {
        return fail("forbidden", 403);
      }
      const claim = await loadHomeworkDailyClaim(svc, school, existing);
      if (claim && text(claim.claimed_by_staff_id) !== linkedStaffId) {
        return fail("homework is claimed by another teacher", 409);
      }
    }
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
    const homework = await loadHomework(svc, school, homeworkId);
    if (!homework) return fail("not found", 404);
    const linkedStaffId = text(user.app_metadata?.linked_id);
    if (role(user) === "teacher") {
      const sectionId = text(homework.section_id);
      if (
        !sectionId || !await teacherCanUseSection(
          svc,
          school,
          linkedStaffId,
          sectionId,
        ) || !await teacherCanUseSubject(
          svc,
          school,
          linkedStaffId,
          sectionId,
          text(homework.subject_id),
        )
      ) return fail("forbidden", 403);
    } else if (role(user) !== "parent" && !isSchoolLeader(user)) {
      return fail("forbidden", 403);
    }
    let query = svc.from("homework_submissions").select(
      "*, students (first_name, last_name)",
    ).eq(
      "school_id",
      school,
    ).eq("homework_id", homeworkId);
    const studentId = text(url.searchParams.get("student_id"));
    if (role(user) === "parent") {
      const { data: links, error: linksError } = await svc.from(
        "parent_student_links",
      ).select("student_id").eq("school_id", school).eq(
        "parent_user_id",
        user.id,
      );
      if (linksError) return fail(linksError.message);
      const linkedStudentIds = (links ?? []).map((link) =>
        text(link.student_id)
      )
        .filter(Boolean);
      if (studentId && !linkedStudentIds.includes(studentId)) {
        return fail("student not linked to parent", 403);
      }
      if (studentId) {
        query = query.eq("student_id", studentId);
      } else if (linkedStudentIds.length > 0) {
        query = query.in("student_id", linkedStudentIds);
      } else {
        return ok({ submissions: [], total: 0 });
      }
    } else if (studentId) {
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
    if (!(await parentCanAccessStudent(svc, user, school, studentId))) {
      return fail("student not linked to parent", 403);
    }
    const homework = await loadHomework(svc, school, homeworkId);
    if (!homework) return fail("homework not found", 404);
    const studentSection = await studentSectionId(svc, school, studentId);
    if (
      text(homework.student_id) && text(homework.student_id) !== studentId ||
      !text(homework.student_id) && text(homework.section_id) !== studentSection
    ) {
      return fail("homework is not assigned to this student", 403);
    }
    const fileUrls = Array.isArray(body.attachment_urls)
      ? body.attachment_urls.map(stableStorageReference).filter(Boolean)
      : [];
    const attachmentUrl = stableStorageReference(body.attachment_url);
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
      const hwTitle = text(hw.title, "Dairy");
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
        title: `Dairy Submitted: ${hwTitle}`,
        body: notifBody,
        type: "homework",
        entity_type: "homework",
        entity_id: text((data as Record<string, unknown>).id),
        is_read: false,
        priority: "high",
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
                title: `Dairy Submitted: ${hwTitle}`,
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

    return ok(
      await materializeHomeworkAttachments(
        svc,
        submissionPayload(data as Record<string, unknown>),
      ),
    );
  }

  const reviewMatch = suffix.match(/^submissions\/([^/]+)\/review$/);
  if (reviewMatch && (method === "PUT" || method === "PATCH")) {
    const homework = await loadHomework(svc, school, homeworkId);
    if (!homework) return fail("homework not found", 404);
    if (role(user) === "teacher") {
      const linkedStaffId = text(user.app_metadata?.linked_id);
      const sectionId = text(homework.section_id);
      if (
        !linkedStaffId || !sectionId ||
        !await teacherCanUseSection(svc, school, linkedStaffId, sectionId) ||
        !await teacherCanUseSubject(
          svc,
          school,
          linkedStaffId,
          sectionId,
          text(homework.subject_id),
        )
      ) return fail("forbidden", 403);
      const claim = await loadHomeworkDailyClaim(svc, school, homework);
      if (!claim || text(claim.claimed_by_staff_id) !== linkedStaffId) {
        return fail("homework is claimed by another teacher", 409);
      }
    } else if (!isSchoolLeader(user)) {
      return fail("forbidden", 403);
    }
    const reviewStatus = text(body.status, "reviewed");
    const reviewRemarks = text(body.remarks);
    if (reviewStatus === "reviewed" && !reviewRemarks) {
      return fail("feedback is required before marking the dairy done", 422);
    }
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
    const hwTitle = text(hw?.title, "Dairy");
    if (studentId) {
      const { data: linkRows } = await svc.from("parent_student_links")
        .select("parent_user_id")
        .eq("school_id", school)
        .eq("student_id", studentId);
      if (linkRows && linkRows.length > 0) {
        const feedbackTitle = reviewStatus === "reviewed"
          ? `Dairy Approved: ${hwTitle}`
          : `Dairy Needs Revision: ${hwTitle}`;
        const feedbackBody = reviewRemarks.length > 0
          ? reviewRemarks
          : (reviewStatus === "reviewed"
            ? "Your child's dairy has been approved by the teacher."
            : "Your child's dairy needs revision. Please check the feedback.");
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
          priority: "high",
          route: "/parent-homework-screen/submit",
          student_id: studentId,
        }));
        const { error: notificationError } = await svc.from(
          "notification_logs",
        ).upsert(parentNotifs.map((notification) => ({
          ...notification,
          created_at: new Date().toISOString(),
        })), { onConflict: "user_id,entity_type,entity_id" });
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
                  title: feedbackTitle,
                  message: feedbackBody,
                  reference_type: "homework",
                  reference_id: homeworkId,
                  action: reviewStatus === "reviewed"
                    ? "approved"
                    : "needs_revision",
                  route: "/parent-homework-screen/submit",
                  student_id: studentId,
                },
              }).select("id").maybeSingle();
            if (eventRow?.id) eventIds.push(eventRow.id);
          }
          triggerPushProcessing(eventIds);
        } catch (_) { /* best-effort */ }
      }
    }

    return ok(
      await materializeHomeworkAttachments(
        svc,
        submissionPayload(submissionRow),
      ),
    );
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

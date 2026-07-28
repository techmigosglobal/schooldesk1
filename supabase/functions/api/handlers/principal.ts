// handlers/principal.ts — classes hub CRUD, subject workflows, imports, timetable
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok, triggerPushProcessing } from "../index.ts";
import { isSchoolLeader, roleName } from "./authorization.ts";

function sid(user: User) {
  return (user.app_metadata?.school_id as string) ?? "";
}

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function uuidText(value: unknown) {
  const raw = text(value);
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(raw)
    ? raw
    : "";
}

function uuidList(value: unknown) {
  return Array.isArray(value) ? value.map(uuidText).filter(Boolean) : [];
}

function integer(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function decimal(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function bool(value: unknown, fallback = false) {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (["true", "1", "yes"].includes(normalized)) return true;
    if (["false", "0", "no"].includes(normalized)) return false;
  }
  return fallback;
}

function classId(path: string) {
  const match = path.match(/^\/principal\/classes\/([^/]+)$/);
  return match?.[1] ?? "";
}

function splitList(value: unknown) {
  const raw = text(value);
  if (!raw) return [];
  return raw.split(";").map((item) => item.trim()).filter(Boolean);
}

function at(values: string[], index: number, fallback = "") {
  return values[index] ?? fallback;
}

function deriveGradeNumber(gradeName: string, explicit: unknown) {
  const parsed = integer(explicit);
  if (parsed !== null && parsed > 0) return parsed;
  const match = gradeName.match(/\d+/);
  if (match) {
    const fromName = parseInt(match[0], 10);
    if (Number.isFinite(fromName) && fromName > 0) return fromName;
  }
  return 1;
}

async function firstRow(query: any) {
  const { data, error } = await query;
  if (error) throw new Error(error.message);
  return data?.[0] ?? null;
}

function normalizeHeader(value: string) {
  return value.trim().toLowerCase().replace(/\s+/g, "_");
}

function parseCsv(textValue: string) {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < textValue.length; i++) {
    const char = textValue[i];
    if (char === '"') {
      if (inQuotes && textValue[i + 1] === '"') {
        field += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char === "," && !inQuotes) {
      row.push(field);
      field = "";
      continue;
    }
    if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && textValue[i + 1] === "\n") i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
      continue;
    }
    field += char;
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows.filter((csvRow) => csvRow.some((cell) => cell.trim().length > 0));
}

function csvObjects(csvText: string) {
  const parsed = parseCsv(csvText);
  if (parsed.length < 2) return [];
  const headers = parsed[0].map(normalizeHeader);
  return parsed.slice(1).map((values, index) => {
    const row: Record<string, string> = { row_number: `${index + 2}` };
    headers.forEach((header, cellIndex) => {
      row[header] = (values[cellIndex] ?? "").trim();
    });
    return row;
  }).filter((row) =>
    Object.entries(row).some(([key, value]) =>
      key !== "row_number" && value.trim().length > 0
    )
  );
}

async function resolveAcademicYearId(
  svc: SupabaseClient,
  school: string,
  row: Record<string, string>,
) {
  const explicitId = uuidText(row.academic_year_id);
  if (explicitId) return explicitId;
  const yearLabel = text(row.year_label);
  if (!yearLabel) return "";
  const match = await firstRow(
    svc.from("academic_years").select("*").eq("school_id", school).eq(
      "year_label",
      yearLabel,
    ).limit(1),
  );
  return text(match?.id);
}

async function resolveDepartmentId(
  svc: SupabaseClient,
  school: string,
  departmentName: string,
) {
  if (!departmentName) return null;
  const existing = await firstRow(
    svc.from("departments").select("*").eq("school_id", school).ilike(
      "department_name",
      departmentName,
    ).limit(1),
  );
  if (existing) return text(existing.id);
  const { data, error } = await svc.from("departments").insert({
    school_id: school,
    department_name: departmentName,
  }).select().single();
  if (error) throw new Error(error.message);
  return text(data.id);
}

async function resolveGrade(
  svc: SupabaseClient,
  school: string,
  body: Record<string, unknown>,
) {
  const gradeId = uuidText(body.grade_id);
  const gradeName = text(body.grade_name);
  const gradeNumber = deriveGradeNumber(gradeName, body.grade_number);

  // If an explicit grade_id is provided, update that grade directly.
  if (gradeId) {
    const { data, error } = await svc.from("grades").update({
      grade_name: gradeName || undefined,
      grade_number: gradeNumber,
      updated_at: new Date().toISOString(),
    }).eq("id", gradeId).eq("school_id", school).select().single();
    if (error) throw new Error(error.message);
    return data;
  }

  // --- No explicit grade_id: try to find or create ---

  // 1) Match by grade_name (case-insensitive) — this is the primary
  //    lookup.  If the user typed "Daycare" we find the existing
  //    "Daycare" grade and reuse it (correct behaviour for multiple
  //    sections under the same grade).
  let grade = null;
  if (gradeName) {
    grade = await firstRow(
      svc.from("grades").select("*").eq("school_id", school).ilike(
        "grade_name",
        gradeName,
      ).order("created_at", { ascending: true }).limit(1),
    );
  }

  // 2) Only if the name lookup found nothing AND the caller did NOT
  //    provide an explicit grade_number, fall back to grade_number.
  //    We still only reuse when the existing grade has an EMPTY name
  //    (e.g. a placeholder row) — this prevents silently renaming an
  //    unrelated grade that happens to share the same number.
  if (!grade && integer(body.grade_number) === null) {
    const byNumber = await firstRow(
      svc.from("grades").select("*").eq("school_id", school).eq(
        "grade_number",
        gradeNumber,
      ).order("created_at", { ascending: true }).limit(1),
    );
    // Only adopt a grade-by-number when its name is blank — otherwise
    // it belongs to a different user-intended grade.
    if (byNumber && !text(byNumber["grade_name"])) {
      grade = byNumber;
    }
  }

  if (grade) {
    const { data, error } = await svc.from("grades").update({
      grade_name: gradeName || grade["grade_name"],
      grade_number: gradeNumber,
      updated_at: new Date().toISOString(),
    }).eq("id", grade["id"]).eq("school_id", school).select().single();
    if (error) throw new Error(error.message);
    return data;
  }

  // No match — create a brand-new grade.
  const { data, error } = await svc.from("grades").insert({
    school_id: school,
    grade_name: gradeName || `Class ${gradeNumber}`,
    grade_number: gradeNumber,
  }).select().single();
  if (error) throw new Error(error.message);
  return data;
}

async function resolveRoom(
  svc: SupabaseClient,
  school: string,
  body: Record<string, unknown>,
) {
  const roomId = uuidText(body.room_id);
  const roomNumber = text(body.room_number);
  const roomType = text(body.room_type) || "classroom";
  const capacity = integer(body.room_capacity);

  if (!roomId && !roomNumber) return null;

  if (roomId) {
    const { data, error } = await svc.from("rooms").update({
      ...(roomNumber ? { room_number: roomNumber } : {}),
      room_type: roomType,
      ...(capacity !== null ? { capacity } : {}),
      updated_at: new Date().toISOString(),
    }).eq("id", roomId).eq("school_id", school).select().single();
    if (error) throw new Error(error.message);
    return data;
  }

  const existing = await firstRow(
    svc.from("rooms").select("*").eq("school_id", school).eq(
      "room_number",
      roomNumber,
    ).order("created_at", { ascending: true }).limit(1),
  );
  if (existing) {
    const { data, error } = await svc.from("rooms").update({
      room_type: roomType,
      ...(capacity !== null ? { capacity } : {}),
      updated_at: new Date().toISOString(),
    }).eq("id", existing["id"]).eq("school_id", school).select().single();
    if (error) throw new Error(error.message);
    return data;
  }

  const { data, error } = await svc.from("rooms").insert({
    school_id: school,
    room_number: roomNumber,
    room_type: roomType,
    ...(capacity !== null ? { capacity } : {}),
  }).select().single();
  if (error) throw new Error(error.message);
  return data;
}

async function resolveStaffId(
  svc: SupabaseClient,
  school: string,
  value: unknown,
  emailValue?: unknown,
) {
  const explicitId = text(value);
  if (explicitId) {
    if (uuidText(explicitId)) {
      const byId = await firstRow(
        svc.from("staff").select("*").eq("school_id", school).eq(
          "id",
          explicitId,
        )
          .limit(1),
      );
      if (byId) return text(byId.id);
    }
    const byCode = await firstRow(
      svc.from("staff").select("*").eq("school_id", school).ilike(
        "staff_code",
        explicitId,
      ).limit(1),
    );
    if (byCode) return text(byCode.id);
  }
  const email = text(emailValue);
  if (email) {
    const byEmail = await firstRow(
      svc.from("staff").select("*").eq("school_id", school).ilike(
        "email",
        email,
      ).limit(1),
    );
    if (byEmail) return text(byEmail.id);
  }
  return "";
}

async function resolveSubjectId(
  svc: SupabaseClient,
  school: string,
  mapping: Record<string, unknown>,
) {
  const explicitId = uuidText(mapping.subject_id);
  if (explicitId) return explicitId;

  const subjectCode = text(mapping.subject_code);
  const subjectName = text(mapping.subject_name);
  if (subjectCode) {
    const byCode = await firstRow(
      svc.from("subjects").select("*").eq("school_id", school).ilike(
        "subject_code",
        subjectCode,
      ).limit(1),
    );
    if (byCode) return text(byCode.id);
  }
  if (subjectName) {
    const byName = await firstRow(
      svc.from("subjects").select("*").eq("school_id", school).ilike(
        "subject_name",
        subjectName,
      ).limit(1),
    );
    if (byName) return text(byName.id);
  }
  if (!subjectName) return "";

  const departmentId = await resolveDepartmentId(
    svc,
    school,
    text(mapping.department_name),
  );
  const { data, error } = await svc.from("subjects").insert({
    school_id: school,
    subject_name: subjectName,
    subject_code: subjectCode || null,
    subject_type: text(mapping.subject_type) || "core",
    department_id: departmentId,
  }).select().single();
  if (error) throw new Error(error.message);
  return text(data.id);
}

async function ensureFeeCategoryId(
  svc: SupabaseClient,
  school: string,
  categoryName: string,
) {
  const existing = await firstRow(
    svc.from("fee_categories").select("*").eq("school_id", school).ilike(
      "name",
      categoryName,
    ).limit(1),
  );
  if (existing) return text(existing.id);
  const { data, error } = await svc.from("fee_categories").insert({
    school_id: school,
    name: categoryName,
  }).select().single();
  if (error) throw new Error(error.message);
  return text(data.id);
}

async function syncFeeItems(
  svc: SupabaseClient,
  school: string,
  gradeId: string,
  sectionId: string,
  academicYearId: string,
  feeItems: unknown,
  deletedFeeStructureIds: string[] = [],
) {
  if (deletedFeeStructureIds.length > 0) {
    await svc.from("fee_structures").delete().in("id", deletedFeeStructureIds)
      .eq(
        "school_id",
        school,
      );
  }
  if (!Array.isArray(feeItems)) return;

  for (const raw of feeItems) {
    const item = (raw ?? {}) as Record<string, unknown>;
    const categoryName = text(item.category_name || item.name);
    if (!categoryName) continue;
    const categoryId = await ensureFeeCategoryId(svc, school, categoryName);
    const payload = {
      school_id: school,
      academic_year_id: academicYearId,
      grade_id: gradeId,
      section_id: sectionId,
      category_id: categoryId,
      amount: decimal(item.amount) ?? 0,
      frequency: text(item.frequency) || "term",
      is_mandatory: item.is_mandatory === undefined
        ? true
        : Boolean(item.is_mandatory),
      due_date: text(item.due_date) || null,
    };
    const feeStructureId = uuidText(item.fee_structure_id || item.id);
    if (feeStructureId) {
      await svc.from("fee_structures").update({
        ...payload,
        updated_at: new Date().toISOString(),
      }).eq("id", feeStructureId).eq("school_id", school);
      continue;
    }
    const existing = await firstRow(
      svc.from("fee_structures").select("*").eq("school_id", school).eq(
        "academic_year_id",
        academicYearId,
      ).eq("grade_id", gradeId).eq("section_id", sectionId).eq(
        "category_id",
        categoryId,
      ).limit(1),
    );
    if (existing) {
      await svc.from("fee_structures").update({
        ...payload,
        updated_at: new Date().toISOString(),
      }).eq("id", existing.id).eq("school_id", school);
    } else {
      await svc.from("fee_structures").insert(payload);
    }
  }
}

async function syncSubjectMappings(
  svc: SupabaseClient,
  school: string,
  gradeId: string,
  sectionId: string,
  academicYearId: string,
  mappings: unknown,
) {
  if (!Array.isArray(mappings)) return;

  for (const raw of mappings) {
    const mapping = (raw ?? {}) as Record<string, unknown>;
    const subjectId = await resolveSubjectId(svc, school, mapping);
    const gradeSubjectId = uuidText(mapping.grade_subject_id || mapping.id);
    const staffSubjectId = uuidText(
      mapping.staff_subject_id || mapping.assignment_id,
    );
    const teacherId = await resolveStaffId(
      svc,
      school,
      mapping.teacher_id || mapping.staff_id,
      mapping.teacher_email,
    );
    const deleting = Boolean(mapping.delete);

    if (deleting) {
      if (gradeSubjectId) {
        await svc.from("grade_subjects").delete().eq("id", gradeSubjectId).eq(
          "school_id",
          school,
        );
      } else if (subjectId) {
        await svc.from("grade_subjects").delete().eq("school_id", school).eq(
          "section_id",
          sectionId,
        ).eq("subject_id", subjectId);
      }
      if (staffSubjectId) {
        await svc.from("staff_subjects").delete().eq("id", staffSubjectId).eq(
          "school_id",
          school,
        );
      } else if (subjectId) {
        await svc.from("staff_subjects").delete().eq("school_id", school).eq(
          "section_id",
          sectionId,
        ).eq("subject_id", subjectId);
      }
      continue;
    }

    if (!subjectId) continue;

    const gradeSubjectPayload = {
      school_id: school,
      academic_year_id: academicYearId,
      grade_id: gradeId,
      section_id: sectionId,
      subject_id: subjectId,
      periods_per_week: integer(mapping.periods_per_week) ?? 5,
      is_mandatory: mapping.is_mandatory === undefined
        ? true
        : Boolean(mapping.is_mandatory),
      is_primary: mapping.is_primary === undefined
        ? true
        : Boolean(mapping.is_primary),
    };

    let savedGradeSubjectId = gradeSubjectId;
    const existingGradeSubject = gradeSubjectId
      ? await firstRow(
        svc.from("grade_subjects").select("*").eq("id", gradeSubjectId).eq(
          "school_id",
          school,
        ).limit(1),
      )
      : await firstRow(
        svc.from("grade_subjects").select("*").eq("school_id", school).eq(
          "section_id",
          sectionId,
        ).eq("subject_id", subjectId).limit(1),
      );
    if (existingGradeSubject) {
      await svc.from("grade_subjects").update({
        ...gradeSubjectPayload,
        updated_at: new Date().toISOString(),
      }).eq("id", existingGradeSubject.id).eq("school_id", school);
      savedGradeSubjectId = text(existingGradeSubject.id);
    } else {
      const inserted = await svc.from("grade_subjects").insert(
        gradeSubjectPayload,
      )
        .select().single();
      if (inserted.error) throw new Error(inserted.error.message);
      savedGradeSubjectId = text(inserted.data.id);
    }

    if (!teacherId) {
      if (staffSubjectId) {
        await svc.from("staff_subjects").delete().eq("id", staffSubjectId).eq(
          "school_id",
          school,
        );
      }
      continue;
    }

    const staffSubjectPayload = {
      school_id: school,
      staff_id: teacherId,
      subject_id: subjectId,
      grade_id: gradeId,
      section_id: sectionId,
      academic_year_id: academicYearId,
      is_primary: mapping.is_primary === undefined
        ? true
        : Boolean(mapping.is_primary),
      periods_per_week: integer(mapping.periods_per_week) ?? 5,
    };

    const existingStaffSubject = staffSubjectId
      ? await firstRow(
        svc.from("staff_subjects").select("*").eq("id", staffSubjectId).eq(
          "school_id",
          school,
        ).limit(1),
      )
      : await firstRow(
        svc.from("staff_subjects").select("*").eq("school_id", school).eq(
          "section_id",
          sectionId,
        ).eq("subject_id", subjectId).limit(1),
      );
    if (existingStaffSubject) {
      await svc.from("staff_subjects").update({
        ...staffSubjectPayload,
        updated_at: new Date().toISOString(),
      }).eq("id", existingStaffSubject.id).eq("school_id", school);
    } else {
      const inserted = await svc.from("staff_subjects").insert(
        staffSubjectPayload,
      )
        .select().single();
      if (inserted.error) throw new Error(inserted.error.message);
    }

    if (savedGradeSubjectId) {
      mapping.grade_subject_id = savedGradeSubjectId;
    }
  }
}

function serializeClassRow(
  section: Record<string, any>,
  grade: Record<string, any> | null,
  room: Record<string, any> | null,
  studentCount = 0,
  feeDues: { amount: number; students: number } = { amount: 0, students: 0 },
  pendingFeeProofs: { amount: number; students: number } = {
    amount: 0,
    students: 0,
  },
  todayAttendancePct: number | null = null,
  includeFees = true,
) {
  const sectionName = text(section["section_name"]);
  const gradeName = text(grade?.["grade_name"]);
  const classTeacher = section["class_teacher"] as Record<string, any> | null;
  const coTeacher = section["co_teacher"] as Record<string, any> | null;

  let pendingIssues = 0;
  if (!section["class_teacher_id"]) {
    pendingIssues++;
  }
  if (studentCount === 0) {
    pendingIssues++;
  }
  if (section["capacity"] && studentCount > Number(section["capacity"])) {
    pendingIssues++;
  }
  if (includeFees && feeDues.amount > 0) {
    pendingIssues++;
  }

  const financeSummary = includeFees
    ? {
      fees_due_amount: feeDues.amount,
      fees_due_students: feeDues.students,
      fees_pending_verification_amount: pendingFeeProofs.amount,
      fees_pending_verification_students: pendingFeeProofs.students,
    }
    : {};

  return {
    ...section,
    section_id: text(section["id"]),
    class_name: [gradeName, sectionName].filter(Boolean).join(" - "),
    grade_id: text(section["grade_id"] || grade?.["id"]),
    grade_name: gradeName,
    grade_number: grade?.["grade_number"] ?? null,
    class_teacher: staffDisplayName(classTeacher),
    co_teacher: staffDisplayName(coTeacher),
    room_id: text(section["room_id"] || room?.["id"]),
    room_number: text(room?.["room_number"]),
    room_type: text(room?.["room_type"]),
    academic_year_id: text(section["academic_year_id"]),
    student_count: studentCount,
    total_students: studentCount,
    ...financeSummary,
    today_attendance_pct: todayAttendancePct,
    pending_issues: pendingIssues,
  };
}

async function studentCountsBySection(
  svc: SupabaseClient,
  school: string,
) {
  const { data, error } = await svc.from("students").select(
    "current_section_id",
  ).eq("school_id", school).eq("status", "active");
  if (error) throw new Error(error.message);
  const counts = new Map<string, number>();
  for (const row of data ?? []) {
    const sectionId = text(row.current_section_id);
    if (!sectionId) continue;
    counts.set(sectionId, (counts.get(sectionId) ?? 0) + 1);
  }
  return counts;
}

async function feeDuesBySection(
  svc: SupabaseClient,
  school: string,
  sectionYears: Map<string, string>,
) {
  const { data, error } = await svc.from("fee_invoices").select(
    "student_id, academic_year_id, balance, status, student:students(current_section_id)",
  ).eq("school_id", school).gt("balance", 0);
  if (error) throw new Error(error.message);
  const totals = new Map<string, { amount: number; studentIds: Set<string> }>();
  for (const row of data ?? []) {
    const student = row.student as Record<string, any> | null;
    const sectionId = text(student?.current_section_id);
    if (!sectionId) continue;
    if (sectionYears.get(sectionId) !== text(row.academic_year_id)) continue;
    if (
      ["cancelled", "void", "paid", "settled"].includes(
        text(row.status).toLowerCase(),
      )
    ) continue;
    const current = totals.get(sectionId) ?? {
      amount: 0,
      studentIds: new Set<string>(),
    };
    current.amount += Number(row.balance ?? 0);
    const studentId = text(row.student_id);
    if (studentId) current.studentIds.add(studentId);
    totals.set(sectionId, current);
  }
  const result = new Map<string, { amount: number; students: number }>();
  for (const [sectionId, total] of totals.entries()) {
    result.set(sectionId, {
      amount: Math.round(total.amount * 100) / 100,
      students: total.studentIds.size,
    });
  }
  return result;
}

async function pendingFeeProofsBySection(
  svc: SupabaseClient,
  school: string,
  sectionYears: Map<string, string>,
) {
  const { data, error } = await svc.from("parent_payment_requests").select(
    "student_id, amount, status, student:students(current_section_id), invoice:fee_invoices(academic_year_id)",
  ).eq("school_id", school).in("status", [
    "pending",
    "submitted",
    "pending_verification",
  ]);
  if (error) throw new Error(error.message);
  const totals = new Map<string, { amount: number; studentIds: Set<string> }>();
  for (const row of data ?? []) {
    const studentValue = row.student as unknown;
    const invoiceValue = row.invoice as unknown;
    const student =
      (Array.isArray(studentValue) ? studentValue[0] : studentValue) as
        | Record<string, unknown>
        | null
        | undefined;
    const invoice =
      (Array.isArray(invoiceValue) ? invoiceValue[0] : invoiceValue) as
        | Record<string, unknown>
        | null
        | undefined;
    const sectionId = text(student?.current_section_id);
    if (!sectionId) continue;
    if (sectionYears.get(sectionId) !== text(invoice?.academic_year_id)) {
      continue;
    }
    const current = totals.get(sectionId) ?? {
      amount: 0,
      studentIds: new Set<string>(),
    };
    current.amount += Number(row.amount ?? 0);
    const studentId = text(row.student_id);
    if (studentId) current.studentIds.add(studentId);
    totals.set(sectionId, current);
  }
  const result = new Map<string, { amount: number; students: number }>();
  for (const [sectionId, total] of totals.entries()) {
    result.set(sectionId, {
      amount: Math.round(total.amount * 100) / 100,
      students: total.studentIds.size,
    });
  }
  return result;
}

async function attendanceBySection(
  svc: SupabaseClient,
  school: string,
) {
  const today = new Date().toISOString().split("T")[0];
  const { data, error } = await svc.from("attendance_sessions").select(
    "id, section_id, student_attendances(status)",
  ).eq("school_id", school).eq("date", today);
  if (error) throw new Error(error.message);

  const pctMap = new Map<string, number>();
  for (const session of data ?? []) {
    const sectionId = text(session.section_id);
    if (!sectionId) continue;
    const attendances =
      session.student_attendances as Array<{ status: string }> ?? [];
    if (attendances.length === 0) continue;
    const present = attendances.filter((a: any) =>
      a.status === "present" || a.status === "late"
    ).length;
    const pct = (present / attendances.length) * 100;
    pctMap.set(sectionId, pct);
  }
  return pctMap;
}

function staffDisplayName(staff: Record<string, any> | null) {
  if (!staff) return "";
  const fullName = [text(staff["first_name"]), text(staff["last_name"])]
    .filter(Boolean)
    .join(" ");
  return fullName || text(staff["name"]) || text(staff["staff_code"]) ||
    text(staff["email"]) || text(staff["id"]);
}

async function createAuditLog(
  svc: SupabaseClient,
  school: string,
  userId: string,
  action: string,
  entityType: string,
  entityId: string,
  details: Record<string, unknown>,
) {
  const { data, error } = await svc.from("audit_logs").insert({
    school_id: school,
    user_id: userId,
    action,
    entity_type: entityType,
    entity_id: entityId,
    details,
  }).select().single();
  if (error) throw new Error(error.message);
  return data;
}

async function notifyStaffIfLinked(
  svc: SupabaseClient,
  school: string,
  staffId: string,
  title: string,
  body: string,
  entityType: string,
  entityId: string,
) {
  if (!staffId) return;
  const userRow = await firstRow(
    svc.from("users").select("*").eq("school_id", school).eq(
      "linked_type",
      "staff",
    ).eq("linked_id", staffId).limit(1),
  );
  if (!userRow) return;
  await svc.from("notification_logs").insert({
    school_id: school,
    user_id: userRow.id,
    title,
    body,
    type: "principal_action",
    entity_type: entityType,
    entity_id: entityId,
  });
  const { data: eventRow } = await svc.from("notification_events").insert({
    school_id: school,
    user_id: userRow.id,
    event_type: entityType,
    event_data: {
      title,
      message: body,
      reference_type: entityType,
      reference_id: entityId,
    },
  }).select("id").maybeSingle();
  if (eventRow?.id) triggerPushProcessing(eventRow.id);
}

async function buildPrincipalSubjectsOverview(
  svc: SupabaseClient,
  school: string,
) {
  const [{ data: gradeSubjects, error: gsError }, {
    data: staffSubjects,
    error: ssError,
  }] = await Promise.all([
    svc.from("grade_subjects").select(
      "*, subject:subjects(*), section:sections(*, grade:grades(*))",
    ).eq("school_id", school),
    svc.from("staff_subjects").select(
      "*, staff:staff(*), section:sections(*, grade:grades(*)), subject:subjects(*)",
    ).eq("school_id", school),
  ]);
  if (gsError) throw new Error(gsError.message);
  if (ssError) throw new Error(ssError.message);

  const subjectsById = new Map<string, Record<string, any>>();
  for (const row of gradeSubjects ?? []) {
    const subject = (row.subject ?? {}) as Record<string, any>;
    const section = (row.section ?? {}) as Record<string, any>;
    const grade = (section.grade ?? {}) as Record<string, any>;
    const subjectId = text(row.subject_id || subject.id);
    if (!subjectId) continue;
    const existing = subjectsById.get(subjectId) ?? {
      subject_id: subjectId,
      subject_name: text(subject.subject_name),
      subject_code: text(subject.subject_code),
      department: text(subject.department_name),
      classes_covered: [] as Array<Record<string, unknown>>,
      assigned_teachers: [] as Array<Record<string, unknown>>,
      teacher_class_coverage: [] as Array<Record<string, unknown>>,
    };
    const classesCovered = existing.classes_covered as Array<
      Record<string, unknown>
    >;
    classesCovered.push({
      "grade_id": text(grade.id || row.grade_id),
      "grade_name": text(grade.grade_name),
      "section_id": text(section.id || row.section_id),
      "section_name": text(section.section_name),
    });
    subjectsById.set(subjectId, existing);
  }

  for (const row of staffSubjects ?? []) {
    const subject = (row.subject ?? {}) as Record<string, any>;
    const staff = (row.staff ?? {}) as Record<string, any>;
    const section = (row.section ?? {}) as Record<string, any>;
    const grade = (section.grade ?? {}) as Record<string, any>;
    const subjectId = text(row.subject_id || subject.id);
    if (!subjectId) continue;
    const existing = subjectsById.get(subjectId) ?? {
      subject_id: subjectId,
      subject_name: text(subject.subject_name),
      subject_code: text(subject.subject_code),
      department: text(subject.department_name),
      classes_covered: [] as Array<Record<string, unknown>>,
      assigned_teachers: [] as Array<Record<string, unknown>>,
      teacher_class_coverage: [] as Array<Record<string, unknown>>,
    };
    (existing.assigned_teachers as Array<Record<string, unknown>>).push({
      "teacher_id": text(staff.id || row.staff_id),
      "name": [text(staff.first_name), text(staff.last_name)].filter(Boolean)
        .join(" ").trim(),
      "designation": text(staff.designation),
      "grade_id": text(grade.id || row.grade_id),
      "grade_name": text(grade.grade_name),
      "section_id": text(section.id || row.section_id),
      "section_name": text(section.section_name),
    });
    (existing.teacher_class_coverage as Array<Record<string, unknown>>).push({
      "teacher_id": text(staff.id || row.staff_id),
      "teacher_name": [text(staff.first_name), text(staff.last_name)].filter(
        Boolean,
      ).join(" ").trim(),
      "grade_name": text(grade.grade_name),
      "section_name": text(section.section_name),
      "is_primary": bool(row.is_primary, true),
    });
    subjectsById.set(subjectId, existing);
  }

  const gradeOptionsMap = new Map<string, Record<string, unknown>>();
  for (const row of gradeSubjects ?? []) {
    const section = (row.section ?? {}) as Record<string, any>;
    const grade = (section.grade ?? {}) as Record<string, any>;
    const gradeId = text(grade.id || row.grade_id);
    if (!gradeId) continue;
    if (!gradeOptionsMap.has(gradeId)) {
      gradeOptionsMap.set(gradeId, {
        "id": gradeId,
        "grade_name": text(grade.grade_name),
        "grade_number": integer(grade.grade_number) ?? 0,
      });
    }
  }

  const subjects = [...subjectsById.values()].map((subject) => {
    const dedupedClasses = new Map<string, Record<string, unknown>>();
    for (
      const row of subject["classes_covered"] as Array<Record<string, unknown>>
    ) {
      dedupedClasses.set(`${row["grade_id"]}:${row["section_id"]}`, row);
    }
    const dedupedTeachers = new Map<string, Record<string, unknown>>();
    for (
      const row of subject["assigned_teachers"] as Array<
        Record<string, unknown>
      >
    ) {
      dedupedTeachers.set(`${row["teacher_id"]}:${row["section_id"]}`, row);
    }
    return {
      ...subject,
      "classes_covered": [...dedupedClasses.values()],
      "assigned_teachers": [...dedupedTeachers.values()],
    };
  });
  subjects.sort((left: any, right: any) =>
    text(left["subject_name"]).localeCompare(text(right["subject_name"]))
  );

  const analytics = {
    "subject_toppers": [] as Array<Record<string, unknown>>,
    "weak_subjects": [] as Array<Record<string, unknown>>,
    "teacher_performance": [] as Array<Record<string, unknown>>,
    "homework_consistency": [] as Array<Record<string, unknown>>,
  };

  return {
    "subjects": subjects,
    "grade_options": [...gradeOptionsMap.values()].sort((left, right) =>
      (integer(left["grade_number"]) ?? 0) -
      (integer(right["grade_number"]) ?? 0)
    ),
    "analytics": analytics,
  };
}

async function validateClassImportRows(
  svc: SupabaseClient,
  school: string,
  rows: Record<string, string>[],
) {
  const previewRows: Array<Record<string, unknown>> = [];
  const errors: Array<Record<string, unknown>> = [];
  const warnings: Array<Record<string, unknown>> = [];
  let validRows = 0;
  let invalidRows = 0;
  let classesToCreate = 0;
  let classesToUpdate = 0;

  for (const row of rows) {
    const rowNumber = integer(row["row_number"]) ?? 0;
    const gradeName = text(row["grade_name"]);
    const sectionName = text(row["section_name"]);
    const academicYearId = await resolveAcademicYearId(svc, school, row);
    if (!gradeName) {
      errors.push({
        "row": rowNumber,
        "field": "grade_name",
        "message": "grade_name is required",
      });
    }
    if (!sectionName) {
      errors.push({
        "row": rowNumber,
        "field": "section_name",
        "message": "section_name is required",
      });
    }
    if (!academicYearId) {
      errors.push({
        "row": rowNumber,
        "field": "academic_year_id",
        "message": "academic_year_id or year_label must match an academic year",
      });
    }
    if (!gradeName || !sectionName || !academicYearId) {
      invalidRows++;
      continue;
    }

    validRows++;
    const gradeNumber = deriveGradeNumber(gradeName, row["grade_number"]);
    const existingGrade = await firstRow(
      svc.from("grades").select("*").eq("school_id", school).ilike(
        "grade_name",
        gradeName,
      ).limit(1),
    );
    const existingSection = existingGrade
      ? await firstRow(
        svc.from("sections").select("*").eq("school_id", school).eq(
          "grade_id",
          text(existingGrade.id),
        ).eq("academic_year_id", academicYearId).ilike(
          "section_name",
          sectionName,
        ).limit(1),
      )
      : null;
    if (existingSection) {
      classesToUpdate++;
    } else {
      classesToCreate++;
    }
    previewRows.push({
      "row_number": rowNumber,
      "mode": existingSection ? "update" : "create",
      "grade_name": gradeName,
      "grade_number": gradeNumber,
      "section_name": sectionName,
      "subject_count": splitList(row["subject_names"]).length,
      "fee_item_count": splitList(row["fee_categories"]).length,
    });
  }

  return {
    "can_import": errors.length === 0 && validRows > 0,
    "summary": {
      "valid_rows": validRows,
      "invalid_rows": invalidRows,
      "classes_to_create": classesToCreate,
      "classes_to_update": classesToUpdate,
    },
    "rows": previewRows,
    "errors": errors,
    "warnings": warnings,
  };
}

async function importClassRows(
  svc: SupabaseClient,
  school: string,
  rows: Record<string, string>[],
) {
  const errors: Array<Record<string, unknown>> = [];
  const warnings: Array<Record<string, unknown>> = [];
  let createdClasses = 0;
  let updatedClasses = 0;

  for (const row of rows) {
    const rowNumber = integer(row["row_number"]) ?? 0;
    try {
      const academicYearId = await resolveAcademicYearId(svc, school, row);
      if (!academicYearId) {
        throw new Error(
          "academic_year_id or year_label must match an academic year",
        );
      }
      const classTeacherId = await resolveStaffId(
        svc,
        school,
        row["class_teacher_id"] || row["class_teacher_staff_code"],
        row["class_teacher_email"],
      );
      const coTeacherId = await resolveStaffId(
        svc,
        school,
        row["co_teacher_id"] || row["co_teacher_staff_code"],
        row["co_teacher_email"],
      );
      const grade = await resolveGrade(svc, school, {
        "grade_name": row["grade_name"],
        "grade_number": row["grade_number"],
      });
      const room = await resolveRoom(svc, school, {
        "room_number": row["room_number"],
        "room_type": row["room_type"],
        "room_capacity": row["room_capacity"],
      });
      const subjectNames = splitList(row["subject_names"]);
      const subjectCodes = splitList(row["subject_codes"]);
      const subjectTypes = splitList(row["subject_types"]);
      const subjectDepartments = splitList(row["subject_departments"]);
      const teacherCodes = splitList(row["subject_teacher_staff_codes"]);
      const teacherEmails = splitList(row["subject_teacher_emails"]);
      const periods = splitList(row["periods_per_week"]);
      const subjectMappings: Array<Record<string, unknown>> = [];
      for (let index = 0; index < subjectNames.length; index++) {
        subjectMappings.push({
          "subject_name": subjectNames[index],
          "subject_code": at(subjectCodes, index),
          "subject_type": at(subjectTypes, index, "core"),
          "department_name": at(subjectDepartments, index, "Academics"),
          "teacher_id": await resolveStaffId(
            svc,
            school,
            at(teacherCodes, index),
            at(teacherEmails, index),
          ),
          "periods_per_week": integer(at(periods, index)) ?? 5,
          "is_mandatory": true,
          "is_primary": true,
        });
      }
      const feeCategories = splitList(row["fee_categories"]);
      const feeAmounts = splitList(row["fee_amounts"]);
      const feeFrequencies = splitList(row["fee_frequencies"]);
      const feeItems: Array<Record<string, unknown>> = [];
      for (let index = 0; index < feeCategories.length; index++) {
        feeItems.push({
          "category_name": feeCategories[index],
          "amount": decimal(at(feeAmounts, index)) ?? 0,
          "frequency": at(feeFrequencies, index, "term"),
        });
      }

      const existingSection = await firstRow(
        svc.from("sections").select("*").eq("school_id", school).eq(
          "grade_id",
          text(grade.id),
        ).eq("academic_year_id", academicYearId).ilike(
          "section_name",
          text(row["section_name"]),
        ).limit(1),
      );

      if (existingSection) {
        const { error } = await svc.from("sections").update({
          "grade_id": text(grade.id),
          "academic_year_id": academicYearId,
          "section_name": text(row["section_name"]),
          "capacity": integer(row["capacity"]) ?? 40,
          "class_teacher_id": classTeacherId || null,
          "co_teacher_id": coTeacherId || null,
          "room_id": room ? text(room.id) : null,
          "sort_order": integer(grade["grade_number"]),
          "updated_at": new Date().toISOString(),
        }).eq("id", existingSection.id).eq("school_id", school);
        if (error) throw new Error(error.message);
        await syncSubjectMappings(
          svc,
          school,
          text(grade.id),
          text(existingSection.id),
          academicYearId,
          subjectMappings,
        );
        await syncFeeItems(
          svc,
          school,
          text(grade.id),
          text(existingSection.id),
          academicYearId,
          feeItems,
        );
        updatedClasses++;
      } else {
        const { data: section, error } = await svc.from("sections").insert({
          "school_id": school,
          "grade_id": text(grade.id),
          "academic_year_id": academicYearId,
          "section_name": text(row["section_name"]),
          "capacity": integer(row["capacity"]) ?? 40,
          "class_teacher_id": classTeacherId || null,
          "co_teacher_id": coTeacherId || null,
          "room_id": room ? text(room.id) : null,
          "sort_order": integer(grade["grade_number"]),
        }).select().single();
        if (error) throw new Error(error.message);
        await syncSubjectMappings(
          svc,
          school,
          text(grade.id),
          text(section.id),
          academicYearId,
          subjectMappings,
        );
        await syncFeeItems(
          svc,
          school,
          text(grade.id),
          text(section.id),
          academicYearId,
          feeItems,
        );
        createdClasses++;
      }
    } catch (error) {
      errors.push({
        "row": rowNumber,
        "field": "import",
        "message": error instanceof Error ? error.message : "Import failed",
      });
    }
  }

  return {
    "summary": {
      "created_classes": createdClasses,
      "updated_classes": updatedClasses,
      "valid_rows": createdClasses + updatedClasses,
    },
    "errors": errors,
    "warnings": warnings,
  };
}

export async function handlePrincipal(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  if (!isSchoolLeader(user)) {
    return fail("school leadership access required", 403);
  }
  const includeFees = roleName(user) !== "coordinator";
  const body = method !== "GET"
    ? await req.json().catch(() => ({})) as Record<string, unknown>
    : {};

  if (path === "/principal/classes" && method === "GET") {
    try {
      const { data, error } = await svc.from("sections").select(
        "*, grade:grades(*), academic_year:academic_years(*), room:rooms(*), class_teacher:staff!sections_class_teacher_id_fkey(*), co_teacher:staff!sections_co_teacher_id_fkey(*)",
      ).eq("school_id", school).order("sort_order", {
        ascending: true,
        nullsFirst: false,
      }).order("created_at", { ascending: true });
      if (error) return fail(error.message);
      const counts = await studentCountsBySection(svc, school);
      const sectionYears = new Map(
        (data ?? []).map((
          row: Record<string, unknown>,
        ) => [text(row.id), text(row.academic_year_id)]),
      );
      const dues = includeFees
        ? await feeDuesBySection(svc, school, sectionYears)
        : new Map<string, { amount: number; students: number }>();
      const pendingFeeProofs = includeFees
        ? await pendingFeeProofsBySection(svc, school, sectionYears)
        : new Map<string, { amount: number; students: number }>();
      const attendancePct = await attendanceBySection(svc, school);
      const classes = (data ?? []).map((row: any) =>
        serializeClassRow(
          row as Record<string, any>,
          (row["grade"] ?? null) as Record<string, any> | null,
          (row["room"] ?? null) as Record<string, any> | null,
          counts.get(text(row["id"])) ?? 0,
          dues.get(text(row["id"])),
          pendingFeeProofs.get(text(row["id"])),
          attendancePct.get(text(row["id"])) ?? null,
          includeFees,
        )
      );
      const totalStudents = classes.reduce(
        (sum: number, item: any) => sum + Number(item.student_count ?? 0),
        0,
      );
      let totalAttendancePct = 0;
      let attendanceCount = 0;
      for (const c of classes) {
        const sid = text(c.section_id);
        if (attendancePct.has(sid)) {
          totalAttendancePct += attendancePct.get(sid)!;
          attendanceCount++;
        }
      }
      const avgAttendance = attendanceCount > 0
        ? (totalAttendancePct / attendanceCount)
        : 0.0;
      const classesWithIssues = classes.filter((c: any) =>
        c.pending_issues > 0
      ).length;

      return ok({
        classes,
        summary: {
          total_classes: classes.length,
          total_students: totalStudents,
          average_attendance: Math.round(avgAttendance),
          classes_with_issues: classesWithIssues,
        },
      });
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "Failed to load classes",
      );
    }
  }

  if (path === "/principal/classes" && method === "POST") {
    try {
      const grade = await resolveGrade(svc, school, body);
      const room = await resolveRoom(svc, school, body);
      const classTeacherId = await resolveStaffId(
        svc,
        school,
        body.class_teacher_id,
      );
      const coTeacherId = await resolveStaffId(svc, school, body.co_teacher_id);
      const academicYearId = await resolveAcademicYearId(
        svc,
        school,
        body as Record<string, string>,
      );
      if (!academicYearId) {
        return fail(
          "academic_year_id or year_label must match an academic year",
        );
      }
      const gradeId = text(grade["id"]);
      const sectionName = text(body.section_name);

      // Guard against duplicate sections: check whether a section with
      // the same grade + section_name + academic_year already exists.
      const existingSection = await firstRow(
        svc.from("sections").select("*").eq("school_id", school).eq(
          "grade_id",
          gradeId,
        ).eq("academic_year_id", academicYearId).ilike(
          "section_name",
          sectionName,
        ).limit(1),
      );
      if (existingSection) {
        return fail(
          `A section named "${sectionName}" already exists for this grade and academic year. Use the edit flow to update it.`,
        );
      }

      const sectionPayload = {
        school_id: school,
        grade_id: gradeId,
        academic_year_id: academicYearId,
        section_name: sectionName,
        capacity: integer(body.capacity),
        class_teacher_id: classTeacherId || null,
        co_teacher_id: coTeacherId || null,
        room_id: room ? text(room["id"]) : null,
        sort_order: integer(grade["grade_number"]),
      };
      const { data: section, error } = await svc.from("sections").insert(
        sectionPayload,
      ).select().single();
      if (error) return fail(error.message);
      await syncSubjectMappings(
        svc,
        school,
        text(grade["id"]),
        text(section["id"]),
        academicYearId,
        body.subject_mappings ?? body.subjects,
      );
      await syncFeeItems(
        svc,
        school,
        text(grade["id"]),
        text(section["id"]),
        academicYearId,
        body.fee_items,
      );
      return ok({
        section,
        grade,
        room,
        class: serializeClassRow(section, grade, room),
      });
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "Failed to create principal class",
      );
    }
  }

  if (path === "/principal/classes/import/dry-run" && method === "POST") {
    try {
      const rows = csvObjects(text(body.csv_text));
      return ok(await validateClassImportRows(svc, school, rows));
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "Failed to dry-run class CSV",
      );
    }
  }

  if (path === "/principal/classes/import" && method === "POST") {
    try {
      const rows = csvObjects(text(body.csv_text));
      return ok(await importClassRows(svc, school, rows));
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "Failed to import class CSV",
      );
    }
  }

  if (path.match(/^\/principal\/classes\/[^/]+$/) && method === "PUT") {
    const sectionId = classId(path);
    try {
      const grade = await resolveGrade(svc, school, body);
      const room = await resolveRoom(svc, school, body);
      const classTeacherId = await resolveStaffId(
        svc,
        school,
        body.class_teacher_id,
      );
      const coTeacherId = await resolveStaffId(svc, school, body.co_teacher_id);
      const academicYearId = await resolveAcademicYearId(
        svc,
        school,
        body as Record<string, string>,
      );
      if (!academicYearId) {
        return fail(
          "academic_year_id or year_label must match an academic year",
        );
      }

      const deletedGradeSubjectIds = uuidList(body.deleted_grade_subject_ids);
      const deletedStaffSubjectIds = uuidList(body.deleted_staff_subject_ids);
      const deletedFeeStructureIds = uuidList(body.deleted_fee_structure_ids);

      if (deletedGradeSubjectIds.length > 0) {
        await svc.from("grade_subjects").delete().in(
          "id",
          deletedGradeSubjectIds,
        ).eq("school_id", school);
      }
      if (deletedStaffSubjectIds.length > 0) {
        await svc.from("staff_subjects").delete().in(
          "id",
          deletedStaffSubjectIds,
        ).eq("school_id", school);
      }

      const { data: section, error } = await svc.from("sections").update({
        grade_id: text(grade["id"]),
        academic_year_id: academicYearId,
        section_name: text(body.section_name),
        capacity: integer(body.capacity),
        class_teacher_id: classTeacherId || null,
        co_teacher_id: coTeacherId || null,
        room_id: room ? text(room["id"]) : null,
        sort_order: integer(grade["grade_number"]),
        updated_at: new Date().toISOString(),
      }).eq("id", sectionId).eq("school_id", school).select().single();
      if (error) return fail(error.message);

      await syncSubjectMappings(
        svc,
        school,
        text(grade["id"]),
        sectionId,
        academicYearId,
        body.subject_mappings ?? body.subjects,
      );
      await syncFeeItems(
        svc,
        school,
        text(grade["id"]),
        sectionId,
        academicYearId,
        body.fee_items,
        deletedFeeStructureIds,
      );

      return ok({
        section,
        grade,
        room,
        class: serializeClassRow(section, grade, room),
      });
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "Failed to update class",
      );
    }
  }

  if (path.match(/^\/principal\/classes\/[^/]+$/) && method === "DELETE") {
    const sectionId = classId(path);
    const { data: section, error: sectionError } = await svc.from("sections")
      .select("id, grade_id").eq("id", sectionId).eq("school_id", school)
      .maybeSingle();
    if (sectionError) return fail(sectionError.message);
    if (!section) return fail("Class not found", 404);

    // Clear fee definitions tied to this class before removing its section.
    // Invoice item snapshots keep historic amounts/names, while the removed
    // class can no longer surface in a fee selector or another module.
    const { error: sectionFeesError } = await svc.from("fee_structures")
      .delete().eq("school_id", school).eq("section_id", sectionId);
    if (sectionFeesError) return fail(sectionFeesError.message);

    const { error } = await svc.from("sections").delete().eq("id", sectionId)
      .eq("school_id", school);
    if (error) return fail(error.message);

    const gradeId = text(section.grade_id);
    let deletedGradeId = "";
    if (gradeId) {
      const { count, error: remainingSectionsError } = await svc
        .from("sections").select("id", { count: "exact", head: true })
        .eq("school_id", school).eq("grade_id", gradeId);
      if (remainingSectionsError) return fail(remainingSectionsError.message);

      // A grade without any section is an orphan from a deleted class. Remove
      // its class-wide fee definitions and the grade itself so it cannot be
      // retrieved by any feature.
      if ((count ?? 0) === 0) {
        const { error: gradeFeesError } = await svc.from("fee_structures")
          .delete().eq("school_id", school).eq("grade_id", gradeId);
        if (gradeFeesError) return fail(gradeFeesError.message);
        const { error: gradeError } = await svc.from("grades").delete()
          .eq("id", gradeId).eq("school_id", school);
        if (gradeError) return fail(gradeError.message);
        deletedGradeId = gradeId;
      }
    }
    return ok({
      success: true,
      section_id: sectionId,
      deleted_grade_id: deletedGradeId,
    });
  }

  if (path === "/principal/subjects" && method === "GET") {
    try {
      return ok(await buildPrincipalSubjectsOverview(svc, school));
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "Failed to load subject command center",
      );
    }
  }

  if (
    path.match(/^\/principal\/subjects\/[^/]+\/actions$/) &&
    method === "POST"
  ) {
    const subjectId = path.split("/")[3];
    try {
      const log = await createAuditLog(
        svc,
        school,
        user.id,
        text(body.action_type) || "subject_action",
        "subject",
        subjectId,
        {
          title: text(body.title),
          message: text(body.message),
          priority: text(body.priority) || "normal",
          grade_id: text(body.grade_id),
          teacher_id: text(body.teacher_id),
          due_date: text(body.due_date),
        },
      );
      await notifyStaffIfLinked(
        svc,
        school,
        text(body.teacher_id),
        text(body.title) || "Subject action",
        text(body.message),
        "subject",
        subjectId,
      );
      return ok(log);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "Failed to save subject action",
      );
    }
  }

  if (
    path.match(/^\/principal\/subjects\/[^/]+\/mappings$/) && method === "POST"
  ) {
    const subjectId = path.split("/")[3];
    const teacherId = text(body.teacher_id);
    const assignmentId = text(body.assignment_id);
    const gradeId = text(body.grade_id);
    const academicYearId = text(body.academic_year_id);
    const sectionId = text(body.section_id);
    const payload = {
      ...body,
      subject_id: subjectId,
    };

    try {
      await syncSubjectMappings(
        svc,
        school,
        gradeId,
        sectionId,
        academicYearId,
        [payload],
      );
      const row = await firstRow(
        svc.from("grade_subjects").select("*").eq("school_id", school).eq(
          "section_id",
          sectionId,
        ).eq("subject_id", subjectId).limit(1),
      );
      if (teacherId) {
        const staffRow = assignmentId
          ? await firstRow(
            svc.from("staff_subjects").select("*").eq("id", assignmentId).eq(
              "school_id",
              school,
            ).limit(1),
          )
          : await firstRow(
            svc.from("staff_subjects").select("*").eq("school_id", school).eq(
              "section_id",
              sectionId,
            ).eq("subject_id", subjectId).limit(1),
          );
        return ok({ ...row, assignment_id: text(staffRow?.id) });
      }
      return ok(row ?? {});
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "Failed to save subject mapping",
      );
    }
  }

  if (
    path.match(/^\/principal\/subjects\/[^/]+\/mappings\/[^/]+$/) &&
    (method === "PATCH" || method === "DELETE")
  ) {
    const parts = path.split("/");
    const mappingId = parts[5];
    if (method === "DELETE") {
      await svc.from("grade_subjects").delete().eq("id", mappingId).eq(
        "school_id",
        school,
      );
      return ok({ success: true });
    }
    const { max_marks: _m, pass_marks: _p, ...safe } = body;
    const { data, error } = await svc.from("grade_subjects").update({
      ...safe,
      updated_at: new Date().toISOString(),
    }).eq("id", mappingId).eq("school_id", school).select().single();
    if (error) return fail(error.message);
    return ok(data);
  }

  if (path === "/principal/timetable" && method === "GET") {
    const { data, error } = await svc.from("timetable_slots").select(
      "*, section:sections(*, grade:grades(*)), subject:subjects(*), staff:staff(*), room:rooms(*)",
    ).eq("school_id", school);
    if (error) return fail(error.message);
    return ok({ slots: data ?? [], total: data?.length ?? 0 });
  }

  if (path === "/principal/timetable/actions" && method === "POST") {
    try {
      const log = await createAuditLog(
        svc,
        school,
        user.id,
        text(body.action_type) || "timetable_action",
        "timetable_slot",
        text(body.slot_id),
        {
          title: text(body.title),
          message: text(body.message),
          priority: text(body.priority) || "normal",
          due_date: text(body.due_date),
        },
      );
      return ok(log);
    } catch (error) {
      return fail(
        error instanceof Error
          ? error.message
          : "Failed to save timetable action",
      );
    }
  }

  return fail("not found", 404);
}

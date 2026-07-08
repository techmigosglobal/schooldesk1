// handlers/sheets_sync.ts - Google Sheets real-time integration
import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function nullableText(value: unknown): string | null {
  const clean = text(value);
  return clean.length > 0 ? clean : null;
}

function parseDayOfWeek(day: unknown): number {
  const d = String(day ?? "").trim().toLowerCase();
  if (d === "monday" || d === "mon" || d === "1") return 1;
  if (d === "tuesday" || d === "tue" || d === "2") return 2;
  if (d === "wednesday" || d === "wed" || d === "3") return 3;
  if (d === "thursday" || d === "thu" || d === "4") return 4;
  if (d === "friday" || d === "fri" || d === "5") return 5;
  if (d === "saturday" || d === "sat" || d === "6") return 6;
  if (d === "sunday" || d === "sun" || d === "7") return 7;
  return parseInt(d) || 1;
}

export async function handleSheetsSyncStudent(
  req: Request,
  svc: SupabaseClient,
): Promise<Response> {
  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const schoolId = text(body.school_id);
    const studentIdNumber = text(body.student_id_number);
    const firstName = text(body.first_name);
    const lastName = text(body.last_name);

    if (!schoolId) return fail("school_id required");
    if (!studentIdNumber) return fail("student_id_number required");
    if (!firstName) return fail("first_name required");

    // 1. Resolve or Create Section (Class)
    let sectionId: string | null = null;
    const sectionName = text(body.section_name);
    if (sectionName) {
      const { data: sectionData, error: sectionError } = await svc
        .from("sections")
        .select("id")
        .eq("school_id", schoolId)
        .eq("name", sectionName)
        .maybeSingle();

      if (sectionError) return fail(`Section lookup error: ${sectionError.message}`);

      if (sectionData) {
        sectionId = sectionData.id;
      } else {
        // Create the section
        const { data: newSec, error: createSecErr } = await svc
          .from("sections")
          .insert({
            school_id: schoolId,
            name: sectionName,
          })
          .select("id")
          .single();
        if (createSecErr) return fail(`Failed to create section: ${createSecErr.message}`);
        sectionId = newSec.id;
      }
    }

    // 2. Resolve or Create Parent User
    let parentUserId: string | null = null;
    const parentUsername = text(body.parent_username);
    const parentName = text(body.parent_name || body.parent_username);
    const parentPassword = text(body.parent_password) || "Parent@12345"; // fallback

    if (parentUsername) {
      // Check if user already exists
      const { data: userData, error: userError } = await svc
        .from("users")
        .select("id")
        .eq("school_id", schoolId)
        .eq("username", parentUsername)
        .maybeSingle();

      if (userError) return fail(`Parent user lookup error: ${userError.message}`);

      if (userData) {
        parentUserId = userData.id;
      } else {
        // Resolve email
        const parentEmail = text(body.parent_email) || `${parentUsername.toLowerCase().replace(/[^a-z0-9]+/g, "-")}.${schoolId.slice(0, 8)}@schooldesk.local`;
        
        // Create in auth
        const { data: authUser, error: authErr } = await svc.auth.admin.createUser({
          email: parentEmail,
          password: parentPassword,
          email_confirm: true,
          app_metadata: { school_id: schoolId, role_name: "Parent" },
        });

        if (authErr) return fail(`Failed to create parent auth: ${authErr.message}`);

        // Insert into users
        const { data: newUser, error: insertUserErr } = await svc
          .from("users")
          .insert({
            id: authUser.user!.id,
            school_id: schoolId,
            username: parentUsername,
            name: parentName,
            email: parentEmail,
            phone: nullableText(body.parent_phone),
            role_name: "Parent",
            is_active: true,
            is_verified: true,
          })
          .select("id")
          .single();

        if (insertUserErr) return fail(`Failed to insert parent user: ${insertUserErr.message}`);
        parentUserId = newUser.id;

        // Upsert username alias
        await svc.from("username_aliases").upsert({
          username: parentUsername.toLowerCase(),
          auth_user_id: authUser.user!.id,
          school_id: schoolId,
        }, { onConflict: "username" });
      }
    }

    // 3. Upsert Student Record (rename systemId to Student ID Number / student_id_number)
    // Check if student exists
    const { data: existingStudent, error: findStudentErr } = await svc
      .from("students")
      .select("id")
      .eq("school_id", schoolId)
      .eq("student_id_number", studentIdNumber)
      .maybeSingle();

    if (findStudentErr) return fail(`Student lookup error: ${findStudentErr.message}`);

    let studentId: string;
    const studentData = {
      school_id: schoolId,
      first_name: firstName,
      last_name: lastName,
      student_id_number: studentIdNumber,
      date_of_birth: nullableText(body.date_of_birth),
      gender: nullableText(body.gender),
      admission_date: nullableText(body.admission_date) || new Date().toISOString().slice(0, 10),
      current_section_id: sectionId,
      status: text(body.status) || "active",
      photo_url: nullableText(body.photo_url),
    };

    if (existingStudent) {
      studentId = existingStudent.id;
      const { error: updateErr } = await svc
        .from("students")
        .update(studentData)
        .eq("id", studentId);
      if (updateErr) return fail(`Failed to update student: ${updateErr.message}`);
    } else {
      const { data: newStudent, error: insertErr } = await svc
        .from("students")
        .insert(studentData)
        .select("id")
        .single();
      if (insertErr) return fail(`Failed to insert student: ${insertErr.message}`);
      studentId = newStudent.id;
    }

    // 4. Resolve Parent-Student Link
    if (parentUserId) {
      const { error: linkErr } = await svc
        .from("parent_student_links")
        .upsert({
          school_id: schoolId,
          parent_user_id: parentUserId,
          student_id: studentId,
        }, { onConflict: "parent_user_id,student_id" });

      if (linkErr) return fail(`Failed to link parent and student: ${linkErr.message}`);
    }

    return ok({ success: true, student_id: studentId });
  } catch (err) {
    return fail(`Sheets sync student error: ${err instanceof Error ? err.message : String(err)}`);
  }
}

export async function handleSheetsSyncTimetable(
  req: Request,
  svc: SupabaseClient,
): Promise<Response> {
  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const schoolId = text(body.school_id);
    const dayValue = body.day_of_week;
    const startTime = text(body.start_time);
    const endTime = text(body.end_time);
    const sectionName = text(body.section_name);

    if (!schoolId) return fail("school_id required");
    if (!dayValue) return fail("day_of_week required");
    if (!startTime) return fail("start_time required");
    if (!endTime) return fail("end_time required");
    if (!sectionName) return fail("section_name required");

    const dayOfWeek = parseDayOfWeek(dayValue);

    // 1. Resolve Academic Year
    const { data: acadYear, error: acadYearErr } = await svc
      .from("academic_years")
      .select("id")
      .eq("school_id", schoolId)
      .eq("is_current", true)
      .maybeSingle();

    if (acadYearErr) return fail(`Academic year lookup error: ${acadYearErr.message}`);

    // 2. Resolve or Create Section (Class)
    let sectionId: string;
    const { data: sectionData, error: sectionError } = await svc
      .from("sections")
      .select("id")
      .eq("school_id", schoolId)
      .eq("name", sectionName)
      .maybeSingle();

    if (sectionError) return fail(`Section lookup error: ${sectionError.message}`);

    if (sectionData) {
      sectionId = sectionData.id;
    } else {
      const { data: newSec, error: createSecErr } = await svc
        .from("sections")
        .insert({
          school_id: schoolId,
          name: sectionName,
        })
        .select("id")
        .single();
      if (createSecErr) return fail(`Failed to create section: ${createSecErr.message}`);
      sectionId = newSec.id;
    }

    // 3. Resolve or Create Subject (if subject_name provided)
    let subjectId: string | null = null;
    const subjectName = text(body.subject_name);
    if (subjectName) {
      const { data: subjectData, error: subjectError } = await svc
        .from("subjects")
        .select("id")
        .eq("school_id", schoolId)
        .eq("subject_name", subjectName)
        .maybeSingle();

      if (subjectError) return fail(`Subject lookup error: ${subjectError.message}`);

      if (subjectData) {
        subjectId = subjectData.id;
      } else {
        const { data: newSub, error: createSubErr } = await svc
          .from("subjects")
          .insert({
            school_id: schoolId,
            subject_name: subjectName,
            subject_type: "core",
          })
          .select("id")
          .single();
        if (createSubErr) return fail(`Failed to create subject: ${createSubErr.message}`);
        subjectId = newSub.id;
      }
    }

    // 4. Resolve Teacher/Staff (if teacher_name provided)
    let staffId: string | null = null;
    const teacherName = text(body.teacher_name);
    if (teacherName) {
      const parts = teacherName.split(" ").filter(Boolean);
      const firstName = parts[0] || "";
      const lastName = parts.slice(1).join(" ") || "";

      let staffQuery = svc.from("staff").select("id").eq("school_id", schoolId);
      if (lastName) {
        staffQuery = staffQuery.ilike("first_name", firstName).ilike("last_name", lastName);
      } else {
        staffQuery = staffQuery.or(`first_name.ilike.%${firstName}%,last_name.ilike.%${firstName}%`);
      }
      const { data: staffData } = await staffQuery.limit(1).maybeSingle();
      if (staffData) {
        staffId = staffData.id;
      }
    }

    // 5. Resolve or Create Room (if room_name provided)
    let roomId: string | null = null;
    const roomName = text(body.room_name);
    if (roomName) {
      const { data: roomData, error: roomError } = await svc
        .from("rooms")
        .select("id")
        .eq("school_id", schoolId)
        .eq("room_number", roomName)
        .maybeSingle();

      if (roomError) return fail(`Room lookup error: ${roomError.message}`);

      if (roomData) {
        roomId = roomData.id;
      } else {
        const { data: newRoom, error: createRoomErr } = await svc
          .from("rooms")
          .insert({
            school_id: schoolId,
            room_number: roomName,
            room_type: "classroom",
          })
          .select("id")
          .single();
        if (createRoomErr) return fail(`Failed to create room: ${createRoomErr.message}`);
        roomId = newRoom.id;
      }
    }

    // 6. Identify Slot Type
    const slotType = text(body.slot_type).toLowerCase() || "regular";
    const validSlotTypes = ["regular", "teaching", "break", "free"];
    const finalSlotType = validSlotTypes.includes(slotType) ? slotType : "regular";

    // 7. Check if Timetable Slot already exists for this Section + Day + Start Time
    const { data: existingSlot, error: findSlotErr } = await svc
      .from("timetable_slots")
      .select("id")
      .eq("school_id", schoolId)
      .eq("section_id", sectionId)
      .eq("day_of_week", dayOfWeek)
      .eq("start_time", startTime)
      .maybeSingle();

    if (findSlotErr) return fail(`Timetable slot lookup error: ${findSlotErr.message}`);

    const slotData = {
      school_id: schoolId,
      section_id: sectionId,
      subject_id: subjectId,
      staff_id: staffId,
      room_id: roomId,
      academic_year_id: acadYear?.id || null,
      day_of_week: dayOfWeek,
      start_time: startTime,
      end_time: endTime,
      period_number: body.period_number ? parseInt(String(body.period_number)) : null,
      slot_type: finalSlotType,
      updated_at: new Date().toISOString(),
    };

    if (existingSlot) {
      const { error: updateErr } = await svc
        .from("timetable_slots")
        .update(slotData)
        .eq("id", existingSlot.id);
      if (updateErr) return fail(`Failed to update timetable slot: ${updateErr.message}`);
    } else {
      const { error: insertErr } = await svc
        .from("timetable_slots")
        .insert({
          ...slotData,
          created_at: new Date().toISOString(),
        });
      if (insertErr) return fail(`Failed to insert timetable slot: ${insertErr.message}`);
    }

    return ok({ success: true });
  } catch (err) {
    return fail(`Sheets sync timetable error: ${err instanceof Error ? err.message : String(err)}`);
  }
}

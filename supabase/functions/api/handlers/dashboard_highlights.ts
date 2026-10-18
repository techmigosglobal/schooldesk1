import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";
import { schoolDay } from "../lib/school_day.ts";
import { resolveActiveTeacherScope } from "./teacher_scope.ts";
import { signedPrivateFileUrl } from "../storage_helpers.ts";

export async function dashboardHighlights(svc: SupabaseClient, user: User) {
  const school = String(user.app_metadata?.school_id || "");
  const role = String(user.app_metadata?.role_name || "").toLowerCase();
  if (!school || !["principal","coordinator","super_admin","teacher","parent"].includes(role)) return fail("forbidden",403);
  const {date} = await schoolDay(svc,school);
  let studentQuery = svc.from("students").select("id,first_name,last_name,date_of_birth,current_section_id,photo_url").eq("school_id",school).ilike("status","active");
  if (role === "teacher") {
    const scope = await resolveActiveTeacherScope(svc,school,String(user.app_metadata?.linked_id || ""));
    const ids = [...scope.sections.keys()];
    if (!ids.length) return ok({date,items:[]});
    studentQuery = studentQuery.in("current_section_id",ids);
  } else if (role === "parent") {
    const {data: links,error} = await svc.from("parent_student_links").select("student_id").eq("school_id",school).eq("parent_user_id",user.id);
    if (error) return fail(error.message);
    const ids = (links || []).map(row=>String(row.student_id));
    if (!ids.length) return ok({date,items:[]});
    studentQuery = studentQuery.in("id",ids);
  }
  const {data:students,error} = await studentQuery;
  if (error) return fail(error.message);
  const studentsById = new Map((students || []).map(row=>[String(row.id),row]));
  const {data: reminders,error:healthError} = await svc.from("health_reminders").select("id,student_id,condition,medication,dosage,reminder_time,notes")
    .eq("school_id",school).eq("reminder_date",date).eq("is_active",true);
  if (healthError) return fail(healthError.message);
  const {data:logs,error:logsError} = await svc.from("notification_logs").select("id,entity_id,is_read,type,student_id,created_at")
    .eq("school_id",school).eq("user_id",user.id).in("type",["health","birthday"]).is("deleted_at",null)
    .order("created_at",{ascending:false});
  if (logsError) return fail(logsError.message);
  const items: Record<string,unknown>[] = [];
  for (const student of students || []) {
    if (String(student.date_of_birth || "").slice(5,10) !== date.slice(5)) continue;
    const log = (logs || []).find(row=>row.type==="birthday" && String(row.student_id)===String(student.id) && String(row.entity_id).includes(date));
    items.push({id:log?.id || `highlight_birthday_${student.id}_${date}`,title:"Birthday Today",body:[student.first_name,student.last_name].filter(Boolean).join(" "),
      type:"birthday",target_role:role,student_id:student.id,section_id:student.current_section_id,
      student_photo_url:await signedPrivateFileUrl(svc,String(student.photo_url || "")),
      reference_type:"birthday",reference_id:student.id,is_read:log?.is_read || false,created_at:`${date}T12:00:00+05:30`,effective_date:date});
  }
  for (const reminder of reminders || []) {
    const student = studentsById.get(String(reminder.student_id));
    if (!student) continue;
    const log = (logs || []).find(row=>String(row.entity_id)===String(reminder.id));
    items.push({id:log?.id || `highlight_health_${reminder.id}`,title:"Health Reminder",body:[student.first_name,student.last_name,reminder.condition,reminder.medication,reminder.dosage,reminder.reminder_time,reminder.notes].filter(Boolean).join(" - "),
      type:"health",target_role:role,student_id:student.id,section_id:student.current_section_id,
      reference_type:"health_reminder",reference_id:reminder.id,is_read:log?.is_read || false,created_at:`${date}T12:00:00+05:30`,effective_date:date,route:"/notification-center-screen"});
  }
  return ok({date,items});
}

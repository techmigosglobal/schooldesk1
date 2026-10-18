import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { resolveActiveTeacherScope } from "./teacher_scope.ts";

// Applied identically to list, count, and read operations. The authenticated
// recipient is authoritative; caller-provided roles/children cannot widen it.
export async function scopeNotificationQuery(query: any, svc: SupabaseClient, user: User) {
  const school = String(user.app_metadata?.school_id || "");
  const role = String(user.app_metadata?.role_name || user.app_metadata?.role || "").trim().toLowerCase();
  query = query.eq("school_id",school).eq("user_id",user.id).is("deleted_at",null)
    .or(`target_role.is.null,target_role.eq.all,target_role.eq.${role}`);
  if (role === "parent") {
    const {data,error} = await svc.from("parent_student_links").select("student_id").eq("school_id",school).eq("parent_user_id",user.id);
    if (error) throw new Error(error.message);
    const ids = (data || []).map(row=>String(row.student_id)).filter(Boolean);
    query = ids.length ? query.or(`student_id.is.null,student_id.in.(${ids.join(",")})`) : query.is("student_id",null);
  } else if (role === "teacher") {
    const staff = String(user.app_metadata?.linked_id || "");
    const scope = await resolveActiveTeacherScope(svc,school,staff);
    const sections = [...scope.sections.keys()];
    const filter = ["type.neq.birthday"];
    if (sections.length) filter.push(`section_id.in.(${sections.join(",")})`);
    if (staff) filter.push(`teacher_id.eq.${staff}`);
    query = query.or(filter.join(","));
  }
  return {query};
}

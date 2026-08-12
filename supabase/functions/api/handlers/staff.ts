// handlers/staff.ts — CRUD, auth-backed staff access, photo upload, documents
import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { cors, fail, ok } from "../index.ts";
import {
  PRIVATE_FILES_BUCKET,
  privateFileReference,
  signedPrivateFileUrl,
} from "../storage_helpers.ts";

function sid(user: User) {
  return (user.app_metadata?.school_id as string) ?? "";
}

function parseId(path: string, prefix: string) {
  const segs = path.slice(prefix.length).split("/").filter(Boolean);
  return segs[0] ?? null;
}

function subPath(path: string, prefix: string) {
  const rest = path.slice(prefix.length);
  const segs = rest.split("/").filter(Boolean);
  return segs.slice(1).join("/");
}

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function numeric(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function staffWriteFields(body: Record<string, unknown>) {
  const patch: Record<string, unknown> = {
    first_name: text(body.first_name),
    last_name: text(body.last_name),
    email: text(body.email),
    phone: text(body.phone),
    gender: text(body.gender),
    designation: text(body.designation),
    employment_type: text(body.employment_type) || "full_time",
    account_role: text(body.account_role).toLowerCase() || "teacher",
  };

  const optionalTextFields = [
    "staff_code",
    "date_of_birth",
    "join_date",
    "photo_url",
  ] as const;
  for (const field of optionalTextFields) {
    const value = text(body[field]);
    if (value) patch[field] = value;
  }

  if (body.department_id !== undefined) {
    patch.department_id = text(body.department_id) || null;
  }

  if (body.is_active !== undefined) {
    patch.is_active = Boolean(body.is_active);
  }

  const salary = numeric(body.basic_salary);
  if (salary !== null) patch.basic_salary = salary;

  return patch;
}

function staffUserFields(
  body: Record<string, unknown>,
  staffId: string,
  school: string,
) {
  const firstName = text(body.first_name);
  const lastName = text(body.last_name);
  const username = text(body.username).toLowerCase();
  const email = text(body.email);
  const phone = text(body.phone);
  const roleName = text(body.account_role).toLowerCase() || "teacher";

  return {
    username,
    email,
    userRow: {
      school_id: school,
      username: username || null,
      name: [firstName, lastName].filter(Boolean).join(" ").trim(),
      email: email || null,
      phone: phone || null,
      role_name: roleName,
      linked_type: "staff",
      linked_id: staffId,
      is_active: body.is_active === undefined ? true : Boolean(body.is_active),
      is_verified: true,
    },
  };
}

function loginEmail(
  body: Record<string, unknown>,
  school: string,
  staffId: string,
) {
  const email = text(body.email);
  if (email) return email;
  const username = text(body.username) || text(body.staff_code) ||
    `staff-${staffId.slice(0, 8)}`;
  const slug =
    username.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") ||
    "staff";
  return `${slug}.${school.slice(0, 8)}@schooldesk.local`;
}

async function linkedUser(
  svc: SupabaseClient,
  school: string,
  staffId: string,
) {
  const { data, error } = await svc.from("users")
    .select("*")
    .eq("school_id", school)
    .eq("linked_type", "staff")
    .eq("linked_id", staffId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return data;
}

async function syncUsernameAlias(
  svc: SupabaseClient,
  school: string,
  authUserId: string,
  username: string,
) {
  await svc.from("username_aliases").delete().eq("auth_user_id", authUserId);
  if (!username) return;
  const { error } = await svc.from("username_aliases").upsert({
    username,
    auth_user_id: authUserId,
    school_id: school,
  }, { onConflict: "username" });
  if (error) throw new Error(error.message);
}

async function provisionStaffLogin(
  svc: SupabaseClient,
  school: string,
  staffId: string,
  body: Record<string, unknown>,
) {
  const password = text(body.password);
  const wantsLogin = Boolean(
    password || text(body.username) || text(body.email),
  );
  if (!wantsLogin) return null;

  const email = loginEmail(body, school, staffId);
  const { username, userRow } = staffUserFields(body, staffId, school);
  const linked = await linkedUser(svc, school, staffId);

  if (!linked) {
    if (!password) return null;
    const { data: authData, error: authErr } = await svc.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: {
        school_id: school,
        role_name: userRow.role_name,
        linked_id: staffId,
      },
    });
    if (authErr) throw new Error(authErr.message);

    const authUserId = authData.user!.id;
    const { error: userErr } = await svc.from("users").insert({
      id: authUserId,
      ...userRow,
    });
    if (userErr) {
      await svc.auth.admin.deleteUser(authUserId).catch(() => undefined);
      throw new Error(userErr.message);
    }
    await syncUsernameAlias(svc, school, authUserId, username);
    return authUserId;
  }

  const authPatch: Record<string, unknown> = {
    email,
    app_metadata: {
      school_id: school,
      role_name: userRow.role_name,
      linked_id: staffId,
    },
  };
  if (password) authPatch.password = password;
  const { error: authErr } = await svc.auth.admin.updateUserById(
    linked.id,
    authPatch,
  );
  if (authErr) throw new Error(authErr.message);

  const { error: userErr } = await svc.from("users").update({
    ...userRow,
    updated_at: new Date().toISOString(),
  }).eq("id", linked.id).eq("school_id", school);
  if (userErr) throw new Error(userErr.message);

  await syncUsernameAlias(svc, school, linked.id, username);
  return linked.id;
}

export async function handleStaff(
  req: Request,
  path: string,
  method: string,
  url: URL,
  _client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = sid(user);
  const id = parseId(path, "/staff");
  const sub = id ? subPath(path, "/staff") : "";

  if (id && sub === "photo" && method === "POST") {
    const form = await req.formData();
    const file = form.get("photo") as File;
    if (!file) return fail("photo required");
    const p = `staff/${school}/${id}/${Date.now()}-${file.name}`;
    await svc.storage.from("school-assets").upload(p, file, {
      upsert: true,
      contentType: file.type || "application/octet-stream",
      cacheControl: "31536000",
    });
    const { data: { publicUrl } } = svc.storage.from("school-assets")
      .getPublicUrl(p);
    await svc.from("staff").update({ photo_url: publicUrl }).eq("id", id);
    return ok({ photo_url: publicUrl });
  }

  if (id && sub === "documents" && method === "POST") {
    const form = await req.formData();
    const file = form.get("document") as File;
    const docType = (form.get("doc_type") as string) ?? "other";
    if (!file) return fail("document required");
    const p = `${school}/staff-documents/${id}/${Date.now()}-${file.name}`;
    const { error: uploadError } = await svc.storage.from(PRIVATE_FILES_BUCKET)
      .upload(p, file, {
        upsert: true,
        contentType: file.type || "application/octet-stream",
        cacheControl: "3600",
      });
    if (uploadError) return fail(uploadError.message);
    const { data, error } = await svc.from("staff_documents").insert({
      staff_id: id,
      school_id: school,
      doc_type: docType,
      title: ((form.get("title") as string) ?? "").trim(),
      file_url: privateFileReference(p),
    }).select().single();
    if (error) return fail(error.message);
    return ok({
      ...data,
      file_url: await signedPrivateFileUrl(svc, data.file_url),
    });
  }

  if (!id && method === "GET") {
    const page = parseInt(url.searchParams.get("page") ?? "1");
    const size = parseInt(url.searchParams.get("page_size") ?? "50");
    const search = url.searchParams.get("search") ?? "";
    let q = svc.from("staff").select(
      "*, department:departments(*), documents:staff_documents(*)",
      {
      count: "exact",
      },
    ).eq("school_id", school).range((page - 1) * size, page * size - 1);
    if (url.searchParams.get("status")) {
      q = q.eq("is_active", url.searchParams.get("status") === "active");
    }
    if (search) {
      q = q.or(
        `first_name.ilike.%${search}%,last_name.ilike.%${search}%,email.ilike.%${search}%`,
      );
    }
    const { data, error, count } = await q;
    if (error) return fail(error.message);
    for (const row of data ?? []) {
      row.documents = await Promise.all(
        (Array.isArray(row.documents) ? row.documents : []).map(
          async (document) => ({
            ...document,
            file_url: await signedPrivateFileUrl(svc, document.file_url),
          }),
        ),
      );
    }
    return cors({
      success: true,
      data: data ?? [],
      total: count ?? 0,
      page,
      page_size: size,
    });
  }

  if (!id && method === "POST") {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const patch = staffWriteFields(body);
    const { data, error } = await svc.from("staff").insert({
      ...patch,
      school_id: school,
    }).select().single();
    if (error) return fail(error.message);
    try {
      await provisionStaffLogin(svc, school, data.id, body);
    } catch (loginError) {
      await svc.from("staff").delete().eq("id", data.id).eq(
        "school_id",
        school,
      );
      return fail(
        loginError instanceof Error
          ? loginError.message
          : "Failed to provision staff login",
      );
    }
    return ok(data);
  }

  if (id && method === "GET") {
    const { data, error } = await svc.from("staff")
      .select(
        "*, department:departments(*), documents:staff_documents(*), staff_qualifications(*)",
      )
      .eq("id", id)
      .eq("school_id", school)
      .single();
    if (error) return fail(error.message);
    return ok({
      ...data,
      documents: await Promise.all(
        (Array.isArray(data.documents) ? data.documents : []).map(
          async (document) => ({
            ...document,
            file_url: await signedPrivateFileUrl(svc, document.file_url),
          }),
        ),
      ),
    });
  }

  if (id && (method === "PUT" || method === "PATCH")) {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const patch = {
      ...staffWriteFields(body),
      updated_at: new Date().toISOString(),
    };
    const { data, error } = await svc.from("staff").update(patch)
      .eq("id", id)
      .eq("school_id", school)
      .select()
      .single();
    if (error) return fail(error.message);
    try {
      await provisionStaffLogin(svc, school, id, body);
    } catch (loginError) {
      return fail(
        loginError instanceof Error
          ? loginError.message
          : "Failed to sync staff login",
      );
    }
    return ok(data);
  }

  if (id && method === "DELETE") {
    try {
      const linked = await linkedUser(svc, school, id);
      if (linked) {
        await svc.from("username_aliases").delete().eq(
          "auth_user_id",
          linked.id,
        );
        await svc.from("users").delete().eq("id", linked.id).eq(
          "school_id",
          school,
        );
        await svc.auth.admin.deleteUser(linked.id);
      }
    } catch (error) {
      return fail(
        error instanceof Error ? error.message : "Failed to remove staff login",
      );
    }
    const { error } = await svc.from("staff").delete().eq("id", id).eq(
      "school_id",
      school,
    );
    if (error) return fail(error.message);
    return ok({ success: true });
  }

  return fail("not found", 404);
}

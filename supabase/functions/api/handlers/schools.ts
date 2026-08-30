// handlers/schools.ts
import {
  SupabaseClient,
  User as _User,
} from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function isSchoolAdministrator(user: _User) {
  const role = `${
    user.app_metadata?.role_name ?? user.app_metadata?.role ?? ""
  }`
    .trim().toLowerCase();
  return ["principal", "coordinator", "admin", "super_admin"].includes(role);
}

async function withAuthorizedSignatureUrl(
  svc: SupabaseClient,
  school: Record<string, unknown>,
) {
  const path = `${school.authorized_signature_path ?? ""}`.trim();
  if (!path) return { ...school, authorized_signature_url: "" };
  const { data, error } = await svc.storage.from("school-signatures")
    .createSignedUrl(path, 3600);
  return {
    ...school,
    authorized_signature_url: error ? "" : data.signedUrl,
  };
}

export async function handleSchools(
  req: Request,
  path: string,
  method: string,
  _url: URL,
  client: SupabaseClient | null,
  svc: SupabaseClient,
): Promise<Response> {
  // School provisioning is intentionally local-seed-only. Keep this guard in
  // the handler while route removal rolls out so every direct invocation fails
  // closed without parsing a body or creating any database/Auth records.
  if (path === "/schools/setup") {
    return fail("not found", 404);
  }

  if (!client) return fail("unauthorized", 401);

  // GET /schools/current
  if (
    (path === "/schools/current" || path === "/schools") && method === "GET"
  ) {
    const { data: { user } } = await client.auth.getUser();
    if (!user) return fail("unauthorized", 401);
    const { data: profile } = await svc.from("users").select("school_id").eq(
      "id",
      user.id,
    ).single();
    const { data: school, error } = await svc.from("schools").select("*").eq(
      "id",
      profile?.school_id,
    ).single();
    if (error) return fail(error.message);
    const organizationId = `${school.organization_id ?? ""}`.trim();
    const [{ data: organization }, profileSchool] = await Promise.all([
      organizationId
        ? svc.from("organizations").select("name").eq(
          "id",
          organizationId,
        ).maybeSingle()
        : Promise.resolve({ data: null }),
      withAuthorizedSignatureUrl(svc, school),
    ]);
    // The database column is registration_no. Keep the legacy response alias
    // during the mobile rollout, but never write it back as a phantom column.
    return ok({
      ...profileSchool,
      registration_number:
        (profileSchool as Record<string, unknown>)?.registration_no ?? "",
      // The school row is the operational branch. Branch-only users see the
      // organization (school) name in their header, not an internal branch
      // label or switcher.
      organization_name: `${organization?.name ?? school.name ?? ""}`.trim(),
      branch_name: `${school.name ?? ""}`.trim(),
    });
  }

  // PATCH /schools/current
  if (path === "/schools/current" && method === "PATCH") {
    const body = await req.json().catch(() => ({}));
    const { data: { user } } = await client.auth.getUser();
    if (!user || !isSchoolAdministrator(user)) return fail("forbidden", 403);
    const { data: profile } = await svc.from("users").select("school_id").eq(
      "id",
      user!.id,
    ).single();
    const { authorized_signature_path: _ignoredSignature, ...rawUpdates } =
      body;
    // Map the legacy request key before the PostgREST update. A direct spread
    // used to make PostgREST look for a nonexistent registration_number field.
    const { registration_number, ...updates } = rawUpdates;
    if (
      registration_number !== undefined &&
      updates.registration_no === undefined
    ) {
      updates.registration_no = registration_number;
    }
    const { data: school, error } = await svc
      .from("schools")
      .update({ ...updates, updated_at: new Date().toISOString() })
      .eq("id", profile?.school_id)
      .select()
      .single();
    if (error) return fail(error.message);
    return ok(school);
  }

  // POST /schools/current/logo — multipart upload
  if (path === "/schools/current/logo" && method === "POST") {
    const form = await req.formData();
    const file = form.get("logo") as File;
    if (!file) return fail("logo file required");
    const { data: { user } } = await client.auth.getUser();
    const { data: profile } = await svc.from("users").select("school_id").eq(
      "id",
      user!.id,
    ).single();
    const path2 = `logos/${profile?.school_id}/${Date.now()}-${file.name}`;
    const { error } = await svc.storage.from("school-assets").upload(
      path2,
      file,
      {
        upsert: true,
        contentType: file.type || "application/octet-stream",
        cacheControl: "31536000",
      },
    );
    if (error) return fail(error.message);
    const { data: { publicUrl } } = svc.storage.from("school-assets")
      .getPublicUrl(path2);
    await svc.from("schools").update({ logo_url: publicUrl }).eq(
      "id",
      profile?.school_id,
    );
    return ok({ logo_url: publicUrl });
  }

  // POST /schools/current/signature — private principal authorization image
  if (path === "/schools/current/signature" && method === "POST") {
    const { data: { user } } = await client.auth.getUser();
    if (!user || !isSchoolAdministrator(user)) return fail("forbidden", 403);
    const form = await req.formData().catch(() => null);
    const file = form?.get("signature") as File | null;
    if (!file) return fail("signature image required");
    const fileName = file.name.toLowerCase();
    const supportedMime = ["image/jpeg", "image/png", "image/webp"].includes(
      file.type,
    );
    const supportedExtension = /\.(jpe?g|png|webp)$/.test(fileName);
    if (!supportedMime && !supportedExtension) {
      return fail("signature must be a JPEG, PNG, or WebP image");
    }
    if (file.size > 5 * 1024 * 1024) {
      return fail("signature image must be 5 MB or smaller");
    }
    const { data: profile, error: profileError } = await svc.from("users")
      .select("school_id").eq("id", user.id).single();
    if (profileError || !profile?.school_id) {
      return fail(profileError?.message ?? "school profile not found");
    }
    const { data: currentSchool } = await svc.from("schools")
      .select("authorized_signature_path").eq("id", profile.school_id)
      .maybeSingle();
    const previousSignaturePath = String(
      currentSchool?.authorized_signature_path ?? "",
    ).trim();
    const extension = file.type === "image/png" || fileName.endsWith(".png")
      ? "png"
      : file.type === "image/webp" || fileName.endsWith(".webp")
      ? "webp"
      : "jpg";
    const signaturePath =
      `signatures/${profile.school_id}/${Date.now()}-${crypto.randomUUID()}.${extension}`;
    const { error: uploadError } = await svc.storage.from("school-signatures")
      .upload(signaturePath, file, {
        contentType: extension === "png"
          ? "image/png"
          : extension === "webp"
          ? "image/webp"
          : "image/jpeg",
        upsert: false,
      });
    if (uploadError) return fail(uploadError.message);
    const { error: updateError } = await svc.from("schools").update({
      authorized_signature_path: signaturePath,
      updated_at: new Date().toISOString(),
    }).eq("id", profile.school_id);
    if (updateError) {
      await svc.storage.from("school-signatures").remove([signaturePath]);
      return fail(updateError.message);
    }
    if (previousSignaturePath && previousSignaturePath !== signaturePath) {
      await svc.storage.from("school-signatures").remove([
        previousSignaturePath,
      ]);
    }
    const { data: signed, error: signedError } = await svc.storage.from(
      "school-signatures",
    ).createSignedUrl(signaturePath, 3600);
    if (signedError) return fail(signedError.message);
    return ok({
      authorized_signature_path: signaturePath,
      authorized_signature_url: signed.signedUrl,
    });
  }

  return fail("not found", 404);
}

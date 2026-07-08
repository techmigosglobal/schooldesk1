import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";

function schoolId(user: User): string {
  return (user.app_metadata?.school_id as string) ?? "";
}

function userId(user: User): string {
  return user.id ?? "";
}

export async function handleNotifications(
  req: Request,
  path: string,
  method: string,
  url: URL,
  client: SupabaseClient,
  svc: SupabaseClient,
  user: User,
): Promise<Response> {
  const school = schoolId(user);
  const uid = userId(user);

  if (!school || !uid) {
    return fail("unauthorized", 401);
  }

  // POST /notifications/register-token — Register device FCM token
  if (path === "/notifications/register-token" && method === "POST") {
    return registerDeviceToken(req, svc, school, uid);
  }

  // POST /notifications/revoke-token — Revoke device FCM token
  if (path === "/notifications/revoke-token" && method === "POST") {
    return revokeDeviceToken(req, svc, school, uid);
  }

  // GET /notifications/preferences — Get user notification preferences
  if (path === "/notifications/preferences" && method === "GET") {
    return getNotificationPreferences(svc, school, uid);
  }

  // PUT /notifications/preferences — Update user notification preferences
  if (path === "/notifications/preferences" && method === "PUT") {
    return updateNotificationPreferences(req, svc, school, uid);
  }

  // POST /notifications/subscribe — Subscribe to notification topic
  if (path === "/notifications/subscribe" && method === "POST") {
    return subscribeToChannel(req, svc, school, uid);
  }

  // POST /notifications/unsubscribe — Unsubscribe from notification topic
  if (path === "/notifications/unsubscribe" && method === "POST") {
    return unsubscribeFromChannel(req, svc, school, uid);
  }

  return fail("not found", 404);
}

async function registerDeviceToken(
  req: Request,
  svc: SupabaseClient,
  school: string,
  userId: string,
): Promise<Response> {
  try {
    const body = await req.json() as Record<string, unknown>;
    const fcmToken = body.fcm_token as string;
    const deviceType = body.device_type as string;

    if (!fcmToken || !fcmToken.trim()) {
      return fail("fcm_token required");
    }

    // Check if notification_devices table exists
    const { data: checkTable, error: checkError } = await svc
      .from("notification_devices")
      .select("id")
      .limit(1);

    if (checkError && checkError.code === "PGRST116") {
      // Table doesn't exist, create it
      return fail("notification_devices table not configured");
    }

    // ── CRITICAL: Deactivate this token for ALL other users first ─────────
    // A physical device can only belong to one user at a time. When a user
    // logs in and registers the same FCM token, any previous user who held
    // that token must lose it — otherwise the notification processor will
    // send push notifications to the wrong user.
    await svc
      .from("notification_devices")
      .update({ is_active: false })
      .eq("school_id", school)
      .eq("fcm_token", fcmToken)
      .neq("user_id", userId);

    // Also clean up the deprecated legacy table so the processor doesn't
    // pick up stale rows from there.
    await svc
      .from("notification_device_tokens")
      .delete()
      .eq("token", fcmToken)
      .neq("user_id", userId);

    // Deactivate any other active tokens for the current user
    await svc
      .from("notification_devices")
      .update({ is_active: false })
      .eq("school_id", school)
      .eq("user_id", userId)
      .neq("fcm_token", fcmToken);

    // Insert or update device token for the current user
    const { error } = await svc
      .from("notification_devices")
      .upsert({
        school_id: school,
        user_id: userId,
        fcm_token: fcmToken,
        device_type: deviceType || "unknown",
        last_registered_at: new Date().toISOString(),
        is_active: true,
      }, {
        onConflict: "school_id,user_id,fcm_token",
      });

    if (error) {
      return fail(`Failed to register token: ${error.message}`);
    }

    return ok({ message: "Device token registered successfully" });
  } catch (error) {
    return fail(`Error registering token: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function revokeDeviceToken(
  req: Request,
  svc: SupabaseClient,
  school: string,
  userId: string,
): Promise<Response> {
  try {
    const body = await req.json() as Record<string, unknown>;
    const fcmToken = body.fcm_token as string;

    if (!fcmToken || !fcmToken.trim()) {
      return fail("fcm_token required");
    }

    const { error } = await svc
      .from("notification_devices")
      .update({ is_active: false })
      .eq("school_id", school)
      .eq("user_id", userId)
      .eq("fcm_token", fcmToken);

    if (error) {
      return fail(`Failed to revoke token: ${error.message}`);
    }

    return ok({ message: "Device token revoked successfully" });
  } catch (error) {
    return fail(`Error revoking token: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function getNotificationPreferences(
  svc: SupabaseClient,
  school: string,
  userId: string,
): Promise<Response> {
  try {
    const { data, error } = await svc
      .from("notification_preferences")
      .select("*")
      .eq("school_id", school)
      .eq("user_id", userId)
      .single();

    if (error && error.code !== "PGRST116") {
      return fail(`Failed to get preferences: ${error.message}`);
    }

    // Return default preferences if not found
    const preferences = data || {
      school_id: school,
      user_id: userId,
      enable_push: true,
      enable_email: true,
      enable_sms: false,
      announcements: true,
      attendance: true,
      fees: true,
      academics: true,
      events: true,
      messages: true,
      emergency_alerts: true,
    };

    return ok(preferences);
  } catch (error) {
    return fail(`Error getting preferences: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function updateNotificationPreferences(
  req: Request,
  svc: SupabaseClient,
  school: string,
  userId: string,
): Promise<Response> {
  try {
    const body = await req.json() as Record<string, unknown>;
    const preferences = {
      school_id: school,
      user_id: userId,
      ...body,
      updated_at: new Date().toISOString(),
    };

    const { error } = await svc
      .from("notification_preferences")
      .upsert(preferences, {
        onConflict: "school_id,user_id",
      });

    if (error) {
      return fail(`Failed to update preferences: ${error.message}`);
    }

    return ok({ message: "Preferences updated successfully" });
  } catch (error) {
    return fail(`Error updating preferences: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function subscribeToChannel(
  req: Request,
  svc: SupabaseClient,
  school: string,
  userId: string,
): Promise<Response> {
  try {
    const body = await req.json() as Record<string, unknown>;
    const channelId = body.channel_id as string;

    if (!channelId || !channelId.trim()) {
      return fail("channel_id required");
    }

    const { error } = await svc
      .from("notification_subscriptions")
      .insert({
        school_id: school,
        user_id: userId,
        channel_id: channelId,
        subscribed_at: new Date().toISOString(),
      });

    if (error && error.code !== "23505") { // Ignore unique constraint violations
      return fail(`Failed to subscribe: ${error.message}`);
    }

    return ok({ message: "Subscribed to channel successfully" });
  } catch (error) {
    return fail(`Error subscribing: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function unsubscribeFromChannel(
  req: Request,
  svc: SupabaseClient,
  school: string,
  userId: string,
): Promise<Response> {
  try {
    const body = await req.json() as Record<string, unknown>;
    const channelId = body.channel_id as string;

    if (!channelId || !channelId.trim()) {
      return fail("channel_id required");
    }

    const { error } = await svc
      .from("notification_subscriptions")
      .delete()
      .eq("school_id", school)
      .eq("user_id", userId)
      .eq("channel_id", channelId);

    if (error) {
      return fail(`Failed to unsubscribe: ${error.message}`);
    }

    return ok({ message: "Unsubscribed from channel successfully" });
  } catch (error) {
    return fail(`Error unsubscribing: ${error instanceof Error ? error.message : String(error)}`);
  }
}

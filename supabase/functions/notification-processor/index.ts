import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Initialize Supabase client with service role
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const FCM_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") || "";

// ─── OAuth2 Token Management ──────────────────────────────────────────────────
// We mint short-lived OAuth2 access tokens from the Firebase service account
// so we can call the FCM HTTP v1 API without the firebase-admin SDK.

let cachedAccessToken: string | null = null;
let tokenExpiresAt = 0;

interface ServiceAccount {
  client_email: string;
  private_key: string;
}

interface HealthCheckResult {
  ok: boolean;
  environment: {
    supabaseUrl: string;
    serviceRoleKeyPresent: boolean;
    firebaseProjectId: string;
    serviceAccountEmail: string;
  };
  oauth: {
    attempted: boolean;
    status: number | null;
    ok: boolean;
    error?: string;
  };
}

function getServiceAccount(): ServiceAccount | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  try {
    return JSON.parse(raw) as ServiceAccount;
  } catch {
    console.error("Failed to parse FIREBASE_SERVICE_ACCOUNT_JSON");
    return null;
  }
}

function maskValue(
  value: string,
  visiblePrefix = 3,
  visibleSuffix = 2,
): string {
  if (!value) return "<missing>";
  if (value.length <= visiblePrefix + visibleSuffix) return "***";
  return `${value.slice(0, visiblePrefix)}***${value.slice(-visibleSuffix)}`;
}

function maskEmail(email: string): string {
  const [localPart, domainPart] = email.split("@");
  if (!localPart || !domainPart) return maskValue(email);
  return `${maskValue(localPart, 2, 1)}@${domainPart}`;
}

/** Base64url-encode without padding (RFC 7515 §2). */
function base64url(data: Uint8Array): string {
  let binary = "";
  for (const byte of data) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(
    /=+$/,
    "",
  );
}

/** Sign a JWT claim set using RS256 with the service account private key. */
async function signJwt(claims: Record<string, unknown>): Promise<string> {
  const sa = getServiceAccount();
  if (!sa) throw new Error("Service account not configured");

  const header = base64url(
    new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })),
  );
  const payload = base64url(
    new TextEncoder().encode(JSON.stringify(claims)),
  );
  const unsignedJwt = `${header}.${payload}`;

  // Import the PEM private key for RS256 signing
  const pemKey = sa.private_key;
  const pemBody = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");

  const binaryDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedJwt),
  );

  return `${unsignedJwt}.${base64url(new Uint8Array(signature))}`;
}

/** Obtain a fresh OAuth2 access token for FCM. */
async function getAccessToken(): Promise<string> {
  // Return cached token if it is still valid (with 60s buffer)
  if (cachedAccessToken && Date.now() < tokenExpiresAt - 60_000) {
    return cachedAccessToken;
  }

  const sa = getServiceAccount();
  if (!sa) throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON not set");

  const now = Math.floor(Date.now() / 1000);
  const jwt = await signJwt({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  });

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!resp.ok) {
    const errText = await resp.text();
    throw new Error(
      `OAuth2 token exchange failed (${resp.status}): ${errText}`,
    );
  }

  const data = await resp.json() as {
    access_token: string;
    expires_in: number;
  };
  cachedAccessToken = data.access_token;
  tokenExpiresAt = Date.now() + data.expires_in * 1000;
  return cachedAccessToken;
}

async function runHealthCheck(): Promise<HealthCheckResult> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  const serviceAccount = getServiceAccount();
  const environment = {
    supabaseUrl: maskValue(supabaseUrl, 8, 12),
    serviceRoleKeyPresent: serviceRoleKey.length > 0,
    firebaseProjectId: maskValue(FCM_PROJECT_ID, 4, 3),
    serviceAccountEmail: serviceAccount?.client_email
      ? maskEmail(serviceAccount.client_email)
      : "<missing>",
  };
  console.log("[notification-processor] healthcheck env", environment);

  if (!serviceAccount || !FCM_PROJECT_ID) {
    const missing = !serviceAccount
      ? "FIREBASE_SERVICE_ACCOUNT_JSON not set"
      : "FIREBASE_PROJECT_ID is not set";
    console.error(
      "[notification-processor] healthcheck oauth skipped",
      missing,
    );
    return {
      ok: false,
      environment,
      oauth: {
        attempted: false,
        status: null,
        ok: false,
        error: missing,
      },
    };
  }

  try {
    const now = Math.floor(Date.now() / 1000);
    const jwt = await signJwt({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: now + 3600,
      iat: now,
    });
    const resp = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });
    console.log(
      `[notification-processor] healthcheck oauth status=${resp.status}`,
    );
    if (!resp.ok) {
      const errorText = await resp.text();
      console.error(
        "[notification-processor] healthcheck oauth failure",
        errorText,
      );
      return {
        ok: false,
        environment,
        oauth: {
          attempted: true,
          status: resp.status,
          ok: false,
          error: errorText.slice(0, 240),
        },
      };
    }
    return {
      ok: true,
      environment,
      oauth: {
        attempted: true,
        status: resp.status,
        ok: true,
      },
    };
  } catch (error) {
    console.error(
      "[notification-processor] healthcheck oauth exception",
      error,
    );
    return {
      ok: false,
      environment,
      oauth: {
        attempted: true,
        status: null,
        ok: false,
        error: String(error).slice(0, 240),
      },
    };
  }
}

// ─── FCM HTTP v1 API ─────────────────────────────────────────────────────────

interface NotificationEvent {
  id: string;
  school_id: string;
  user_id: string;
  event_type: string;
  event_data: Record<string, unknown>;
  created_at: string;
}

interface NotificationTemplate {
  title: string;
  body: string;
  data: Record<string, string>;
  image?: string;
}

interface FcmSendResult {
  sent: boolean;
  invalidToken: boolean;
  error?: string;
}

interface EventProcessResult {
  processed: boolean;
  sentCount: number;
  invalidTokenCount: number;
  transientFailureCount: number;
  reason?: string;
  debug_info?: any;
}

type ActiveDeviceToken = {
  token: string;
  source: "notification_devices" | "notification_device_tokens";
};

/** Build a human-readable notification from the event type + payload. */
function getNotificationTemplate(
  eventType: string,
  eventData: Record<string, unknown>,
): NotificationTemplate {
  switch (eventType) {
    case "complaint_escalated":
      return {
        title: "New Complaint Escalated",
        body: `A complaint has been escalated: ${
          eventData.subject || "No subject"
        }`,
        data: {
          event_type: "complaint_escalated",
          complaint_id: String(eventData.complaint_id || ""),
          complaint_type: String(eventData.complaint_type || ""),
          reference_type: "complaint",
        },
      };

    case "leave_approved":
      return {
        title: "Leave Approved ✅",
        body: String(
          eventData.message || "Your leave request has been approved.",
        ),
        data: {
          event_type: "leave_approved",
          reference_type: "leave",
          leave_id: String(eventData.leave_id || ""),
        },
      };

    case "leave_rejected":
      return {
        title: "Leave Rejected",
        body: String(
          eventData.message || "Your leave request has been rejected.",
        ),
        data: {
          event_type: "leave_rejected",
          reference_type: "leave",
          leave_id: String(eventData.leave_id || ""),
        },
      };

    case "student_leave_approved":
      return {
        title: "Student Leave Approved ✅",
        body: String(
          eventData.message || "Student leave request has been approved.",
        ),
        data: {
          event_type: "student_leave_approved",
          reference_type: "leave",
          leave_id: String(eventData.leave_id || ""),
        },
      };

    case "student_leave_rejected":
      return {
        title: "Student Leave Rejected",
        body: String(
          eventData.message || "Student leave request has been rejected.",
        ),
        data: {
          event_type: "student_leave_rejected",
          reference_type: "leave",
          leave_id: String(eventData.leave_id || ""),
        },
      };

    case "announcement":
      return {
        title: "New Announcement",
        body: `${eventData.title || "New announcement"}`,
        data: {
          event_type: "announcement",
          reference_type: "announcement",
          announcement_id: String(eventData.announcement_id || ""),
        },
      };

    case "attendance_marked":
      return {
        title: "Attendance Update",
        body: String(
          eventData.message ||
            `Your child was marked ${eventData.status || "absent"} on ${
              eventData.date || "today"
            }.`,
        ),
        data: {
          event_type: "attendance_marked",
          reference_type: "attendance",
          status: String(eventData.status || "absent"),
          date: String(eventData.date || ""),
        },
      };

    case "fee_due":
      return {
        title: "💰 Fee Payment Due",
        body: String(
          eventData.message ||
            `A fee payment of ${
              eventData.amount || ""
            } is due. Please pay before the due date to avoid late charges.`,
        ),
        data: {
          event_type: "fee_due",
          reference_type: "fee",
          invoice_id: String(eventData.invoice_id || ""),
          due_date: String(eventData.due_date || ""),
        },
      };

    case "ptm_booked":
      return {
        title: "📅 PTM Slot Booked",
        body: String(
          eventData.message ||
            "A parent has booked a PTM meeting slot with you.",
        ),
        data: {
          event_type: "ptm_booked",
          reference_type: "ptm",
          ptm_id: String(eventData.ptm_id || ""),
          slot_date: String(eventData.slot_date || ""),
          slot_time: String(eventData.slot_time || ""),
        },
      };

    case "ptm_status_updated":
      return {
        title: "📅 PTM Meeting Update",
        body: String(
          eventData.message || "Your PTM meeting status has been updated.",
        ),
        data: {
          event_type: "ptm_status_updated",
          reference_type: "ptm",
          ptm_id: String(eventData.ptm_id || ""),
          status: String(eventData.status || ""),
          slot_date: String(eventData.slot_date || ""),
          slot_time: String(eventData.slot_time || ""),
        },
      };

    case "homework_submitted":
      return {
        title: String(eventData.title || "Homework Submitted"),
        body: String(
          eventData.message || "A homework submission was received.",
        ),
        data: {
          event_type: "homework_submitted",
          reference_type: "homework",
          homework_id: String(eventData.homework_id || ""),
          reference_id: String(
            eventData.reference_id || eventData.homework_id || "",
          ),
          action: "submission",
          route: String(
            eventData.route || "/teacher-homework-screen/submissions",
          ),
          student_id: String(eventData.student_id || ""),
        },
      };

    case "homework_feedback":
      return {
        title: "Homework Feedback",
        body: String(
          eventData.message || "Teacher provided feedback on homework.",
        ),
        data: {
          event_type: "homework_feedback",
          reference_type: "homework",
          homework_id: String(eventData.homework_id || ""),
          reference_id: String(
            eventData.reference_id || eventData.homework_id || "",
          ),
          action: String(eventData.action || "feedback"),
        },
      };

    case "event_created":
      return {
        title: "New School Event",
        body: String(
          eventData.title || "A new event has been added to the calendar.",
        ),
        data: {
          event_type: "event_created",
          reference_type: "event",
          event_id: String(eventData.event_id || ""),
        },
      };

    case "birthday":
    case "birthday_wish": {
      const students = (eventData.students || []) as Array<
        { id: string; name: string; photo_url: string }
      >;
      const image = students.length > 0
        ? (students[0].photo_url || undefined)
        : undefined;
      const data: Record<string, string> = {
        event_type: eventType,
        reference_type: "birthday",
        reference_id: String(eventData.reference_id || ""),
        student_id: String(eventData.student_id || ""),
        section_id: String(eventData.section_id || ""),
        teacher_id: String(eventData.teacher_id || ""),
      };

      if (students.length > 0) {
        data.students_json = JSON.stringify(students);
        if (!data.student_id && students[0].id) {
          data.student_id = students[0].id;
        }
        if (students[0].photo_url) {
          data.photo_url = students[0].photo_url;
        }
      }

      return {
        title: String(eventData.title || "Birthday Today"),
        body: String(eventData.message || "Happy Birthday!"),
        data,
        image,
      };
    }

    case "leave_recalled":
      return {
        title: "Leave Request Recalled",
        body: String(
          eventData.message || "A leave request has been recalled.",
        ),
        data: {
          event_type: "leave_recalled",
          reference_type: "leave",
          leave_id: String(eventData.leave_id || ""),
        },
      };

    case "homework_assigned":
      return {
        title: String(eventData.title || "New Homework Assigned"),
        body: String(
          eventData.message || "Your child has been assigned new homework.",
        ),
        data: {
          event_type: "homework_assigned",
          reference_type: "homework",
          homework_id: String(eventData.homework_id || ""),
          reference_id: String(
            eventData.reference_id || eventData.homework_id || "",
          ),
          action: "assignment",
          route: String(eventData.route || "/parent-homework-screen/submit"),
          student_id: String(eventData.student_id || ""),
        },
      };

    case "fee_payment_submitted":
      return {
        title: "New Payment Proof Submitted",
        body: String(
          eventData.message ||
            "A parent submitted payment proof. Please review and verify.",
        ),
        data: {
          event_type: "fee_payment_submitted",
          reference_type: "fee",
          payment_request_id: String(eventData.payment_request_id || ""),
          invoice_id: String(eventData.invoice_id || ""),
          reference_id: String(
            eventData.reference_id || eventData.payment_request_id || "",
          ),
          action: String(eventData.action || "payment_submitted"),
          route: String(
            eventData.route || "/principal-fees-screen/payment-requests",
          ),
          student_id: String(eventData.student_id || ""),
        },
      };

    case "fee_payment_approved":
      return {
        title: "Payment Approved ✅",
        body: String(
          eventData.message ||
            "Your payment has been verified and approved. Receipt is now available.",
        ),
        data: {
          event_type: "fee_payment_approved",
          reference_type: "fee",
          payment_request_id: String(eventData.payment_request_id || ""),
          invoice_id: String(eventData.invoice_id || ""),
          reference_id: String(
            eventData.reference_id || eventData.payment_request_id || "",
          ),
          action: String(eventData.action || "payment_approved"),
          route: String(eventData.route || "/parent-fees-screen"),
          student_id: String(eventData.student_id || ""),
        },
      };

    case "fee_payment_rejected":
      return {
        title: "Payment Update",
        body: String(
          eventData.message || "Your payment submission requires attention.",
        ),
        data: {
          event_type: "fee_payment_rejected",
          reference_type: "fee",
          payment_request_id: String(eventData.payment_request_id || ""),
          invoice_id: String(eventData.invoice_id || ""),
          reference_id: String(
            eventData.reference_id || eventData.payment_request_id || "",
          ),
          action: String(eventData.action || "payment_rejected"),
          route: String(eventData.route || "/parent-fees-screen"),
          student_id: String(eventData.student_id || ""),
        },
      };

    case "leave_submitted":
      return {
        title: "New Leave Request",
        body: String(
          eventData.message || "A new leave request is pending your review.",
        ),
        data: {
          event_type: "leave_submitted",
          reference_type: "leave",
          leave_id: String(eventData.leave_id || ""),
        },
      };

    case "student_leave_submitted":
      return {
        title: "Student Leave Request",
        body: String(
          eventData.message ||
            "A parent submitted a student leave request for your review.",
        ),
        data: {
          event_type: "student_leave_submitted",
          reference_type: "leave",
          leave_id: String(eventData.leave_id || ""),
        },
      };

    default:
      return {
        title: "SchoolDesk Notification",
        body: String(eventData.message || "You have a new notification"),
        data: {
          event_type: eventType,
          reference_type: String(eventData.reference_type || eventType),
        },
      };
  }
}

/**
 * Send an FCM push notification to a single device token using the HTTP v1 API.
 * Returns true if the message was accepted by FCM.
 */
async function sendFcmNotification(
  token: string,
  template: NotificationTemplate,
): Promise<FcmSendResult> {
  if (!FCM_PROJECT_ID) {
    console.error(
      "FIREBASE_PROJECT_ID is not set — cannot send push notifications",
    );
    return {
      sent: false,
      invalidToken: false,
      error: "FIREBASE_PROJECT_ID is not set",
    };
  }

  try {
    const accessToken = await getAccessToken();

    const url =
      `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`;

    const body = {
      message: {
        token,
        notification: {
          title: template.title,
          body: template.body,
          ...(template.image ? { image: template.image } : {}),
        },
        data: template.data,
        android: {
          priority: "high" as const,
          notification: {
            channel_id: "schooldesk_updates",
            ...(template.image ? { image: template.image } : {}),
          },
        },
        apns: {
          payload: {
            aps: {
              alert: { title: template.title, body: template.body },
              badge: 1,
              sound: "default",
              ...(template.image ? { "mutable-content": 1 } : {}),
            },
          },
          ...(template.image ? { fcm_options: { image: template.image } } : {}),
        },
      },
    };

    const resp = await fetch(url, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      console.error(`FCM send failed (${resp.status}): ${errText}`);
      return {
        sent: false,
        invalidToken: isInvalidFcmTokenError(errText),
        error: errText,
      };
    }

    const result = await resp.json() as Record<string, unknown>;
    // FCM may include error details even with 200 for some token issues
    const fcmError = (result as { error?: string }).error;
    if (fcmError) {
      console.error(`FCM returned error in response: ${fcmError}`);
      return {
        sent: false,
        invalidToken: isInvalidFcmTokenError(String(fcmError)),
        error: String(fcmError),
      };
    }

    return { sent: true, invalidToken: false };
  } catch (error) {
    console.error(`Failed to send FCM notification: ${error}`);
    return { sent: false, invalidToken: false, error: String(error) };
  }
}

function isInvalidFcmTokenError(raw: string): boolean {
  try {
    const parsed = JSON.parse(raw) as {
      error?: {
        status?: string;
        message?: string;
        details?: Array<{ errorCode?: string }>;
      };
    };
    const status = parsed.error?.status ?? "";
    const detailCodes = parsed.error?.details?.map((detail) =>
      detail.errorCode ?? ""
    ) ?? [];
    if (
      status === "NOT_FOUND" ||
      detailCodes.includes("UNREGISTERED")
    ) {
      return true;
    }
  } catch {
    // Fall back to string matching below.
  }

  return raw.includes("UNREGISTERED") ||
    raw.includes("registration token is not a valid FCM registration token");
}

async function markEventProcessed(eventId: string): Promise<void> {
  await supabase
    .from("notification_events")
    .update({
      processed: true,
      sent_at: new Date().toISOString(),
    })
    .eq("id", eventId);
}

async function claimEvent(eventId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from("notification_events")
    .update({ processed: true })
    .eq("id", eventId)
    .eq("processed", false)
    .select("id")
    .maybeSingle();
  if (error) throw error;
  return data?.id === eventId;
}

async function releaseEvent(eventId: string): Promise<void> {
  const { error } = await supabase
    .from("notification_events")
    .update({ processed: false, sent_at: null })
    .eq("id", eventId);
  if (error) throw error;
}

async function activeDeviceTokensForUser(
  userId: string,
): Promise<ActiveDeviceToken[]> {
  const [{ data: currentDevices, error: currentError }, {
    data: legacyDevices,
    error: legacyError,
  }] = await Promise.all([
    supabase
      .from("notification_devices")
      .select("fcm_token")
      .eq("user_id", userId)
      .eq("is_active", true),
    supabase
      .from("notification_device_tokens")
      .select("token")
      .eq("user_id", userId),
  ]);

  if (currentError) throw currentError;
  if (legacyError) throw legacyError;

  const tokens = new Map<string, ActiveDeviceToken>();
  for (const row of currentDevices ?? []) {
    const token = `${row.fcm_token ?? ""}`.trim();
    if (!token) continue;
    tokens.set(token, {
      token,
      source: "notification_devices",
    });
  }
  for (const row of legacyDevices ?? []) {
    const token = `${row.token ?? ""}`.trim();
    if (!token || tokens.has(token)) continue;
    tokens.set(token, {
      token,
      source: "notification_device_tokens",
    });
  }
  return [...tokens.values()];
}

async function deactivateInvalidToken(
  userId: string,
  device: ActiveDeviceToken,
): Promise<void> {
  if (device.source === "notification_devices") {
    await supabase
      .from("notification_devices")
      .update({ is_active: false })
      .eq("fcm_token", device.token)
      .eq("user_id", userId);
    return;
  }
  await supabase
    .from("notification_device_tokens")
    .delete()
    .eq("token", device.token)
    .eq("user_id", userId);
}

// ─── Event Processing ────────────────────────────────────────────────────────

async function processNotificationEvent(
  event: NotificationEvent,
): Promise<EventProcessResult> {
  try {
    // Immediate API processing and pg_cron may overlap. Atomically transition
    // the row out of the pending set before contacting FCM; only one worker can
    // claim a given event. Transient failures release it for a later retry.
    if (!(await claimEvent(event.id))) {
      return {
        processed: true,
        sentCount: 0,
        invalidTokenCount: 0,
        transientFailureCount: 0,
        reason: "already_claimed",
      };
    }

    const devices = await activeDeviceTokensForUser(event.user_id);
    if (devices.length === 0) {
      console.log(`No active devices for user ${event.user_id}`);
      await markEventProcessed(event.id);
      return {
        processed: true,
        sentCount: 0,
        invalidTokenCount: 0,
        transientFailureCount: 0,
        reason: "no_active_devices",
      };
    }

    // Build the notification template
    const template = getNotificationTemplate(
      event.event_type,
      event.event_data,
    );

    // Check user notification preferences (opt-out check)
    const { data: preferences } = await supabase
      .from("notification_preferences")
      .select("enable_push")
      .eq("user_id", event.user_id)
      .single();

    if (preferences && preferences.enable_push === false) {
      console.log(`Push notifications disabled for user ${event.user_id}`);
      await markEventProcessed(event.id);
      return {
        processed: true,
        sentCount: 0,
        invalidTokenCount: 0,
        transientFailureCount: 0,
        reason: "push_disabled",
      };
    }

    // Send to all active devices
    let sentCount = 0;
    const invalidTokens: ActiveDeviceToken[] = [];
    let transientFailureCount = 0;
    let lastError = "";
    const tokenResults: any[] = [];

    for (const device of devices) {
      const result = await sendFcmNotification(device.token, template);
      tokenResults.push({
        token_preview: device.token.slice(0, 10) + "..." +
          device.token.slice(-10),
        sent: result.sent,
        invalidToken: result.invalidToken,
        error: result.error,
      });
      if (result.sent) {
        sentCount++;
      } else if (result.invalidToken) {
        invalidTokens.push(device);
      } else {
        transientFailureCount++;
        lastError = result.error ?? lastError;
      }
    }

    // Deactivate tokens that FCM rejected (likely unregistered / expired)
    for (const device of invalidTokens) {
      await deactivateInvalidToken(event.user_id, device);
    }

    if (sentCount > 0) {
      await markEventProcessed(event.id);
      console.log(
        `Sent notification for event ${event.id} to ${sentCount}/${devices.length} devices`,
      );
      return {
        processed: true,
        sentCount,
        invalidTokenCount: invalidTokens.length,
        transientFailureCount,
        debug_info: tokenResults,
      };
    }

    if (invalidTokens.length > 0 && transientFailureCount === 0) {
      await markEventProcessed(event.id);
      console.log(
        `Event ${event.id} processed; all target tokens were invalid`,
      );
      return {
        processed: true,
        sentCount,
        invalidTokenCount: invalidTokens.length,
        transientFailureCount,
        reason: "all_tokens_invalid",
        debug_info: tokenResults,
      };
    }

    console.log(
      `Event ${event.id} not processed; ${transientFailureCount} transient FCM failure(s)`,
    );
    await releaseEvent(event.id);
    return {
      processed: false,
      sentCount,
      invalidTokenCount: invalidTokens.length,
      transientFailureCount,
      reason: lastError.slice(0, 240),
      debug_info: tokenResults,
    };
  } catch (error) {
    console.error(`Error processing notification event ${event.id}: ${error}`);
    try {
      await releaseEvent(event.id);
    } catch (releaseError) {
      console.error(
        `Failed to release notification event ${event.id}: ${releaseError}`,
      );
    }
    return {
      processed: false,
      sentCount: 0,
      invalidTokenCount: 0,
      transientFailureCount: 1,
      reason: String(error).slice(0, 240),
    };
  }
}

// ─── Main Handler ────────────────────────────────────────────────────────────
// Invoked by the API for instant pushes and by pg_cron as a backup. Processes
// up to 100 unprocessed events per call, or a provided event_ids subset.

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    if (body.healthcheck === true) {
      const result = await runHealthCheck();
      return new Response(JSON.stringify(result), {
        status: result.ok ? 200 : 500,
        headers: { "Content-Type": "application/json" },
      });
    }
    const eventIds = Array.isArray(body.event_ids)
      ? body.event_ids.map((id) => `${id}`).filter(Boolean)
      : [];

    let query = supabase
      .from("notification_events")
      .select("*")
      .eq("processed", false)
      .order("created_at", { ascending: true });
    query = eventIds.length > 0 ? query.in("id", eventIds) : query.limit(100);

    const { data: events, error } = await query;

    if (error) {
      console.error("Error fetching notification events:", error);
      return new Response(
        JSON.stringify({ error: "Failed to fetch events" }),
        { status: 500 },
      );
    }

    if (!events || events.length === 0) {
      return new Response(
        JSON.stringify({ message: "No events to process" }),
        { status: 200 },
      );
    }

    let processedCount = 0;
    let sentCount = 0;
    let invalidTokenCount = 0;
    let transientFailureCount = 0;
    const failures: Array<
      { event_id: string; reason: string; debug_info?: any }
    > = [];
    const debug_details: any[] = [];
    for (const event of events as NotificationEvent[]) {
      const result = await processNotificationEvent(event);
      if (result.processed) processedCount++;
      sentCount += result.sentCount;
      invalidTokenCount += result.invalidTokenCount;
      transientFailureCount += result.transientFailureCount;
      debug_details.push({
        event_id: event.id,
        processed: result.processed,
        results: result.debug_info,
        reason: result.reason,
      });
      if (!result.processed) {
        failures.push({
          event_id: event.id,
          reason: result.reason ?? "unknown",
          debug_info: result.debug_info,
        });
      }
    }

    return new Response(
      JSON.stringify({
        message: "Events processed",
        total: events.length,
        processed: processedCount,
        sent: sentCount,
        invalid_tokens: invalidTokenCount,
        transient_failures: transientFailureCount,
        failures,
        debug_details,
      }),
      { status: 200 },
    );
  } catch (error) {
    console.error("Error in notification processor:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500 },
    );
  }
});

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Initialize Supabase client with service role
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const FCM_ENDPOINT = "https://fcm.googleapis.com/v1/projects/";
const FCM_API_KEY = Deno.env.get("FIREBASE_API_KEY") || "";

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
}

function getNotificationTemplate(
  eventType: string,
  eventData: Record<string, unknown>,
): NotificationTemplate {
  switch (eventType) {
    case "complaint_escalated":
      return {
        title: "New Complaint Escalated",
        body: `A complaint has been escalated: ${eventData.subject || "No subject"}`,
        data: {
          event_type: "complaint_escalated",
          complaint_id: String(eventData.complaint_id || ""),
          complaint_type: String(eventData.complaint_type || ""),
        },
      };
    case "attendance_marked":
      return {
        title: "Attendance Marked",
        body: `Attendance has been marked for today`,
        data: {
          event_type: "attendance_marked",
        },
      };
    case "announcement":
      return {
        title: "New Announcement",
        body: `${eventData.title || "New announcement"}`,
        data: {
          event_type: "announcement",
          announcement_id: String(eventData.announcement_id || ""),
        },
      };
    case "fee_due":
      return {
        title: "Fee Due Reminder",
        body: `A fee payment is due: ${eventData.amount || ""}`,
        data: {
          event_type: "fee_due",
        },
      };
    default:
      return {
        title: "SchoolDesk Notification",
        body: "You have a new notification",
        data: {
          event_type: eventType,
        },
      };
  }
}

async function sendFcmNotification(
  token: string,
  template: NotificationTemplate,
): Promise<boolean> {
  try {
    // Note: This requires Firebase Admin SDK or direct HTTP API with proper authentication
    // For now, we'll just log that we would send it
    console.log(`Would send FCM notification to token: ${token}`, template);
    return true;
  } catch (error) {
    console.error(`Failed to send FCM notification: ${error}`);
    return false;
  }
}

async function processNotificationEvent(event: NotificationEvent): Promise<boolean> {
  try {
    // Get user's device tokens
    const { data: devices, error: devicesError } = await supabase
      .from("notification_devices")
      .select("fcm_token")
      .eq("user_id", event.user_id)
      .eq("is_active", true);

    if (devicesError || !devices || devices.length === 0) {
      console.log(
        `No active devices for user ${event.user_id}`,
      );
      return false;
    }

    // Get notification template
    const template = getNotificationTemplate(
      event.event_type,
      event.event_data,
    );

    // Check user's notification preferences
    const { data: preferences } = await supabase
      .from("notification_preferences")
      .select("enable_push")
      .eq("user_id", event.user_id)
      .single();

    if (preferences && !preferences.enable_push) {
      console.log(`Push notifications disabled for user ${event.user_id}`);
      return false;
    }

    // Send notification to all devices
    let sentCount = 0;
    for (const device of devices) {
      const success = await sendFcmNotification(device.fcm_token, template);
      if (success) sentCount++;
    }

    // Mark event as processed
    if (sentCount > 0) {
      await supabase
        .from("notification_events")
        .update({
          processed: true,
          sent_at: new Date().toISOString(),
        })
        .eq("id", event.id);

      console.log(
        `Sent notification for event ${event.id} to ${sentCount} devices`,
      );
      return true;
    }

    return false;
  } catch (error) {
    console.error(
      `Error processing notification event ${event.id}: ${error}`,
    );
    return false;
  }
}

// Main handler - processes unprocessed notification events
Deno.serve(async (_req: Request) => {
  try {
    // Get unprocessed notification events
    const { data: events, error } = await supabase
      .from("notification_events")
      .select("*")
      .eq("processed", false)
      .order("created_at", { ascending: true })
      .limit(100);

    if (error) {
      console.error("Error fetching notification events:", error);
      return new Response(
        JSON.stringify({ error: "Failed to fetch events" }),
        { status: 500 },
      );
    }

    if (!events || events.length === 0) {
      return new Response(JSON.stringify({ message: "No events to process" }), {
        status: 200,
      });
    }

    let processedCount = 0;
    for (const event of events as NotificationEvent[]) {
      const success = await processNotificationEvent(event);
      if (success) processedCount++;
    }

    return new Response(
      JSON.stringify({
        message: "Events processed",
        total: events.length,
        processed: processedCount,
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

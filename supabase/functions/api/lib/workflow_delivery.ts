import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { triggerPushProcessing } from "../index.ts";

// Persistence and queueing are transactional database triggers. Waking the
// processor is an optimization; the scheduled retry owns eventual delivery.
export async function wakeWorkflowDelivery(svc: SupabaseClient, school: string, referenceId: string) {
  const { data, error } = await svc.from("notification_events").select("id")
    .eq("school_id", school).eq("processed", false)
    .eq("event_data->>reference_id", referenceId).limit(100);
  if (error) { console.error("notification processor wake lookup failed", error.message); return; }
  triggerPushProcessing((data ?? []).map((row) => String(row.id)));
}

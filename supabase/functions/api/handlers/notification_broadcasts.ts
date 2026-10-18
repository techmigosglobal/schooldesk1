import { SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";
import { fail, ok } from "../index.ts";
import { wakeWorkflowDelivery } from "../lib/workflow_delivery.ts";

// SQL authorization reads current persisted membership even when a token is stale.
function broadcastErrorStatus(error: {code?: string; message: string}, fallback: number): number {
  return error.code === "42501" ? 403 : fallback;
}

export async function handleNotificationBroadcasts(req: Request,path: string,method: string,url: URL,svc: SupabaseClient,user: User,body: Record<string,unknown>) {
  const school=String(user.app_metadata?.school_id || '');
  const role=String(user.app_metadata?.role_name || user.app_metadata?.role || '').trim().toLowerCase();
  if (role!=='principal' || !school) return fail('Principal access required',403);
  const page=Math.max(1,Number.parseInt(url.searchParams.get('page') || '1') || 1);
  if (path==='/notifications/recipients' && method==='GET') {
    const roles=(url.searchParams.get('roles') || '').split(',').filter(Boolean);
    const {data,error}=await svc.rpc('notification_recipient_search',{p_school:school,p_sender:user.id,p_roles:roles,p_search:(url.searchParams.get('search') || '').slice(0,120),p_page:page});
    return error ? fail(error.message,broadcastErrorStatus(error,400)) : ok(data);
  }
  if (path==='/notifications/broadcasts' && method==='GET') {
    const {data,error}=await svc.rpc('notification_broadcast_history',{p_school:school,p_sender:user.id,p_page:page});
    return error ? fail(error.message,broadcastErrorStatus(error,400)) : ok(data);
  }
  if (path==='/notifications/broadcasts' && method==='POST') {
    const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const key=String(req.headers.get('Idempotency-Key') || '');
    if (!uuid.test(key) || typeof body.title !== 'string' || typeof body.message !== 'string' || !['all','selected'].includes(String(body.mode)) || !Array.isArray(body.roles) || body.roles.some(value=>typeof value !== 'string') || !Array.isArray(body.user_ids) || body.user_ids.length>5000 || body.user_ids.some(id=>!uuid.test(String(id)))) return fail('Invalid notification request',422);
    const {data,error}=await svc.rpc('send_notification_broadcast',{p_school:school,p_sender:user.id,p_key:key,p_title:String(body.title || ''),p_message:String(body.message || ''),p_roles:body.roles,p_mode:body.mode,p_users:body.user_ids});
    if(error) return fail(error.message,broadcastErrorStatus(error,error.message.includes('already used') ? 409 : 422));
    if (!data.replayed) await wakeWorkflowDelivery(svc,school,String(data.id));
    return ok(data);
  }
  return fail('Not found',404);
}

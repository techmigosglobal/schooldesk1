-- PostgREST grants EXECUTE to API roles by default. This function is called
-- exclusively by the Edge API service client and must never be RPC-callable.
revoke execute on function public.record_fee_payment(uuid,uuid,uuid,numeric,text,text,timestamptz,text,uuid,text[],int,uuid) from anon, authenticated;

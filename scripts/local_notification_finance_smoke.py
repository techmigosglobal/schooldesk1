#!/usr/bin/env python3
"""Behavioral custom-notification and finance checks, synthetic Docker only."""
import concurrent.futures
import json
import random
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
CONFIG=json.loads((ROOT/'env.local.json').read_text())
API=CONFIG['API_BASE_URL'].rstrip('/')
assert urllib.parse.urlparse(API).hostname in ('localhost','127.0.0.1','::1'), 'Synthetic local API only'
DB='supabase_db_schooldesk-local'
SCHOOL='00000000-0000-4000-8000-000000000001'
IP=f'198.18.{random.randrange(1,254)}.{random.randrange(1,254)}'
TOKENS={}
def sql(statement):
    p=subprocess.run(['docker','--context','default','exec','-i',DB,'psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-Atq'],input=statement,text=True,capture_output=True)
    assert p.returncode==0,p.stderr
    return p.stdout.strip()
def req(role,path,body=None,method=None,expected=200,key=None):
    headers={'Content-Type':'application/json','x-forwarded-for':IP}
    if role:headers['Authorization']='Bearer '+TOKENS[role]
    if key:headers['Idempotency-Key']=key
    request=urllib.request.Request(API+path,data=None if body is None else json.dumps(body).encode(),headers=headers,method=method or ('GET' if body is None else 'POST'))
    for attempt in range(5):
        try:r=urllib.request.urlopen(request,timeout=60)
        except urllib.error.HTTPError as e:r=e
        with r:
            data=json.load(r)
            if r.status==409 and expected==200 and 'still processing' in str(data.get('error','')) and attempt<4:
                time.sleep(1)
                continue
            assert r.status==expected,(path,r.status,data.get('error'))
            return data.get('data',data)

for role in ['PARENT','TEACHER','PRINCIPAL','COORDINATOR','SUPER_ADMIN','SECOND_SCHOOL_PRINCIPAL']:
    result=req(None,'/auth/login',{'username':CONFIG[f'QA_{role}_USERNAME'],'password':CONFIG[f'QA_{role}_PASSWORD']})
    TOKENS[role]=result.get('access_token') or result['token']

# Repair only incomplete runs of this synthetic script, using the audited RPC.
sql("""do $$ declare p record; actor uuid; begin
  select id into actor from users where school_id='00000000-0000-4000-8000-000000000001' and role_name='principal' limit 1;
  for p in select id,school_id from payments where reference_number like 'LOCAL-REVERSAL-%' and status<>'reversed' loop
    perform public.reverse_fee_payment(p.school_id,p.id,actor,'Restore interrupted local test');
  end loop;
end $$;""")
broadcasts=[]
try:
    sql(f"insert into users(id,school_id,name,username,role_name,is_active) select gen_random_uuid(),'{SCHOOL}','Local broadcast user '||g,'local.broadcast.'||g,'parent',true from generate_series(1,55) g;")
    first=req('PRINCIPAL','/notifications/recipients?roles=parent')
    second=req('PRINCIPAL','/notifications/recipients?roles=parent&page=2')
    assert len(first['items'])==50 and second['items'] and first['total']>50
    found=req('PRINCIPAL','/notifications/recipients?roles=parent&search=Local%20broadcast%20user%2055')
    assert found['total']==1
    for role in ['PARENT','TEACHER','COORDINATOR','SUPER_ADMIN']:
        req(role,'/notifications/recipients?roles=parent',expected=403)
        req(role,'/notifications/broadcasts',{'title':'Forbidden','message':'No send','roles':['parent'],'mode':'all','user_ids':[]},expected=403,key=str(uuid.uuid4()))
    for role in ['PARENT','TEACHER','COORDINATOR']:
        req(role,'/notifications/push-diagnostics',{},expected=403)
    parent=sql(f"select id from users where school_id='{SCHOOL}' and role_name='parent' and username not like 'local.broadcast.%' limit 1;")
    teacher=sql(f"select id from users where school_id='{SCHOOL}' and role_name='teacher' limit 1;")
    foreign=sql(f"select id from users where school_id<>'{SCHOOL}' and role_name='parent' limit 1;")
    payload={'title':'Local principal update','message':'A custom subject and message remain intact.','roles':['parent','teacher'],'mode':'selected','user_ids':[parent,teacher]}
    key=str(uuid.uuid4())
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results=list(pool.map(lambda _:req('PRINCIPAL','/notifications/broadcasts',payload,key=key),range(3)))
    bid=results[0]['id'];broadcasts.append(bid)
    assert len({r['id'] for r in results})==1
    assert sql(f"select count(*) from notification_logs where entity_type='notification_broadcast' and entity_id='{bid}';")=='2'
    assert sql(f"select count(*) from notification_events where event_type='custom_notification' and event_data->>'reference_id'='{bid}';")=='2'
    req('PRINCIPAL','/notifications/broadcasts',{**payload,'message':'Changed content'},expected=409,key=key)
    req('PRINCIPAL','/notifications/broadcasts',{**payload,'user_ids':[foreign]},expected=422,key=str(uuid.uuid4()))
    req('SECOND_SCHOOL_PRINCIPAL','/notifications/broadcasts',payload,expected=422,key=str(uuid.uuid4()))
    for role in ['PARENT','TEACHER']:
        rows=req(role,'/notifications')['items']
        assert any(r['title']==payload['title'] and r['body']==payload['message'] for r in rows)
    all_result=req('PRINCIPAL','/notifications/broadcasts',{'title':'Local all-role message','message':'Across all recipient pages.','roles':['parent'],'mode':'all','user_ids':[]},key=str(uuid.uuid4()))
    broadcasts.append(all_result['id']);assert all_result['recipient_count']==first['total']
    history=req('PRINCIPAL','/notifications/broadcasts')['items']
    assert any(r['id']==bid and r['recipient_count']==2 for r in history)
    # Move a custom subject beyond page one; backend filters must retrieve it.
    sql(f"insert into notification_logs(school_id,user_id,target_role,title,type,entity_type,entity_id) select '{SCHOOL}','{parent}','parent','Newer local row','general','broadcast_test_page',g::text from generate_series(1,65) g;")
    filtered=req('PARENT','/notifications?category=custom_notification&is_read=false')['items']
    assert any(r['entity_id']==bid for r in filtered)
    read_id=next(r['id'] for r in filtered if r['entity_id']==bid)
    req('PARENT','/notifications/'+read_id+'/read',{},method='PUT')
    assert not any(r['id']==read_id for r in req('PARENT','/notifications?category=custom_notification&is_read=false')['items'])
    sql("create function public.local_broadcast_failure() returns trigger language plpgsql as $$ begin if new.event_type='custom_notification' then raise exception 'Synthetic queue failure'; end if; return new; end $$; create trigger local_broadcast_failure before insert on notification_events for each row execute function public.local_broadcast_failure();")
    before=sql('select count(*) from notification_broadcasts;')
    req('PRINCIPAL','/notifications/broadcasts',payload,expected=422,key=str(uuid.uuid4()))
    assert sql('select count(*) from notification_broadcasts;')==before
    sql('drop trigger local_broadcast_failure on notification_events;drop function public.local_broadcast_failure();')
    print('PASS role/individual targeting, >50 recipients, concurrent idempotency, foreign-school rejection, inbox subjects, filtered paging/read, and atomic rollback',flush=True)

    invoice=json.loads(sql(f"select row_to_json(i) from fee_invoices i where school_id='{SCHOOL}' and balance>100 limit 1;"))
    invoice_id=invoice['id'];original=float(invoice['balance'])
    def pay(amount):return req('PRINCIPAL','/fees/payments',{'invoice_id':invoice_id,'amount':amount,'payment_method':'cash','reference_number':'LOCAL-REVERSAL-'+str(uuid.uuid4())})
    first_payment=pay(40); second_payment=pay(original-40)
    p1=first_payment.get('payment_id') or first_payment.get('id')
    p2=second_payment.get('payment_id') or second_payment.get('id')
    assert p1 and p2
    parent_request=str(uuid.uuid4())
    sql(f"insert into parent_payment_requests(id,school_id,student_id,invoice_id,parent_user_id,amount,status,payment_id,payment_method,transaction_ref,request_reference) values('{parent_request}','{SCHOOL}','{invoice['student_id']}','{invoice_id}','{parent}',40,'approved','{p1}','upi','LOCAL-APPROVED','LOCAL-'||gen_random_uuid()::text);")
    def invoice_row():return next(r for r in req('PARENT','/parent/students/'+invoice['student_id']+'/fees') if r['id']==invoice_id)
    assert float(invoice_row()['balance_amount'])==0
    req('PARENT','/fees/payments/'+p1,{'reason':'Unauthorized'},method='DELETE',expected=403)
    req('SECOND_SCHOOL_PRINCIPAL','/fees/payments/'+p1,{'reason':'Foreign'},method='DELETE',expected=404)
    result=req('PRINCIPAL','/fees/payments/'+p1,{'reason':'Local regression correction'},method='DELETE')
    assert float(result['new_balance'])==40 and float(invoice_row()['balance_amount'])==40
    assert sql(f"select status from payments where id='{p1}';")=='reversed'
    assert sql(f"select status from parent_payment_requests where id='{parent_request}';")=='reversed'
    assert sql(f"select bool_and(voided_at is not null) from fee_receipts where payment_id='{p1}';")=='t'
    req('PRINCIPAL','/fees/payments/'+p1,{'reason':'Duplicate'},method='DELETE',expected=409)
    req('PRINCIPAL','/fees/payments/'+p2,{'reason':'Restore synthetic fixture'},method='DELETE')
    assert float(invoice_row()['balance_amount'])==original
    print('PASS full/partial payment, immediate parent retrieval, audited reversal, void receipt, duplicate and foreign-school rejection',flush=True)
finally:
    sql("drop trigger if exists local_broadcast_failure on notification_events;drop function if exists public.local_broadcast_failure();")
    sql("delete from notification_logs where entity_type='broadcast_test_page';")
    for bid in broadcasts:
        sql(f"delete from notification_events where event_type='custom_notification' and event_data->>'reference_id'='{bid}';delete from notification_logs where entity_type='notification_broadcast' and entity_id='{bid}';delete from notification_broadcasts where id='{bid}';")
    sql("delete from users where username like 'local.broadcast.%';")

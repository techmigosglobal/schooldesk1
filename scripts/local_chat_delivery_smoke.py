#!/usr/bin/env python3
"""Synthetic Docker-only behavioral checks; removes its own fixtures on exit."""
import concurrent.futures
import base64
import json
import random
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
CONFIG=json.loads((ROOT/'env.local.json').read_text())
API=CONFIG['API_BASE_URL'].rstrip('/')
assert urllib.parse.urlparse(API).hostname in ('localhost','127.0.0.1','::1'), 'Local API only'
SCHOOL='00000000-0000-4000-8000-000000000001'
STUDENT=str(uuid.uuid4()); UNLINKED=str(uuid.uuid4()); IP=f'198.18.{random.randrange(1,254)}.{random.randrange(1,254)}'
TOKENS={}
def sql(statement,check=True):
 r=subprocess.run(['docker','--context','default','exec','-i','supabase_db_schooldesk-local','psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-Atq'],input=statement,text=True,capture_output=True)
 if check and r.returncode: raise RuntimeError(r.stderr.strip())
 return r.stdout.strip() if check else r

def request(role,path,body=None,expected=200):
 headers={'Content-Type':'application/json','x-forwarded-for':IP}
 if role: headers['Authorization']='Bearer '+TOKENS[role]
 req=urllib.request.Request(API+path,data=None if body is None else json.dumps(body).encode(),headers=headers)
 try: response=urllib.request.urlopen(req,timeout=60)
 except urllib.error.HTTPError as e: response=e
 with response:
  value=json.loads(response.read()); assert response.status==expected,f'{path}: {response.status}: {value}'
  return value.get('data',value)

for role in ('PARENT','TEACHER','PRINCIPAL','COORDINATOR','SECOND_SCHOOL_PARENT','SECOND_SCHOOL_COORDINATOR'):
 result=request(None,'/auth/login',{'username':CONFIG[f'QA_{role}_USERNAME'],'password':CONFIG[f'QA_{role}_PASSWORD']})
 TOKENS[role]=result.get('access_token') or result['token']
fixture=json.loads(sql(f"select jsonb_build_object('parent',(select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_PARENT_USERNAME']}'),'teacher',(select linked_id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_TEACHER_USERNAME']}'),'teacher_user',(select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_TEACHER_USERNAME']}'),'leader',(select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_PRINCIPAL_USERNAME']}'));"))
PARENT,TEACHER,TEACHER_USER,LEADER=[fixture[k] for k in ('parent','teacher','teacher_user','leader')]
section=sql(f"select id from sections where school_id='{SCHOOL}' and (class_teacher_id='{TEACHER}' or co_teacher_id='{TEACHER}') limit 1;")
assert section,'Synthetic teacher must have a class'
foreign=sql(f"select id from students where school_id<>'{SCHOOL}' limit 1;")
CO=str(uuid.uuid4()); CO_STAFF=str(uuid.uuid4()); ids=[]
photo_original=json.loads(sql(f"select coalesce(to_jsonb(avatar),'null'::jsonb) from users where id='{TEACHER_USER}';"))
photo_restore="'"+photo_original.replace("'","''")+"'" if photo_original is not None else 'null'
staff_original=json.loads(sql(f"select coalesce(to_jsonb(photo_url),'null'::jsonb) from staff where id='{TEACHER}';"))
staff_restore="'"+staff_original.replace("'","''")+"'" if staff_original is not None else 'null'
storage_paths=[]
container=json.loads(subprocess.check_output(['docker','--context','default','inspect','supabase_edge_runtime_schooldesk-local']))[0]
service_key=next(v.split('=',1)[1] for v in container['Config']['Env'] if v.startswith('SUPABASE_SERVICE_ROLE_KEY='))
def storage(method,path,payload=None):
 req=urllib.request.Request(CONFIG['SUPABASE_URL'].rstrip('/')+'/storage/v1/object/school-private-files/'+path,data=payload,method=method,headers={'Authorization':'Bearer '+service_key,'Content-Type':'image/png'})
 with urllib.request.urlopen(req,timeout=30) as response: return response.read()
try:
 sql(f"insert into students(id,school_id,first_name,last_name,current_section_id) values('{STUDENT}','{SCHOOL}','Chat','Synthetic','{section}'); insert into students(id,school_id,first_name,last_name,current_section_id) values('{UNLINKED}','{SCHOOL}','Chat','Unlinked','{section}'); insert into parent_student_links(school_id,parent_user_id,student_id) values('{SCHOOL}','{PARENT}','{STUDENT}');")
 scope={'type':'parent_teacher','teacher_id':TEACHER,'parent_id':PARENT,'student_id':STUDENT,'title':'Synthetic chat delivery'}
 teacher_contacts=request('TEACHER','/chat/contacts?role=teacher')
 assert any(c['id']==PARENT and c.get('student_id')==STUDENT for c in teacher_contacts)
 assert any(c.get('type')=='principal_teacher' for c in teacher_contacts)
 assert all(c.get('teacher_id')==TEACHER for c in teacher_contacts), 'Teacher contact tuples require authenticated staff ID'
 print('PASS teacher contacts include canonical authenticated teacher_id for parent and leadership first-contact tuples')
 def send(i=None,**kwargs): return request('PARENT','/chat/messages',dict(scope,client_message_id=i or str(uuid.uuid4()),body='Synthetic atomic chat',**kwargs))
 request('PARENT','/chat/messages',dict(scope,student_id=foreign,client_message_id=str(uuid.uuid4()),body='Forbidden'),403)
 request('PARENT','/chat/messages',dict(scope,student_id=UNLINKED,client_message_id=str(uuid.uuid4()),body='Foreign child'),403)
 wrong=sql(f"select id from staff where school_id='{SCHOOL}' and id<>'{TEACHER}' and not exists(select 1 from sections where id='{section}' and (class_teacher_id=staff.id or co_teacher_id=staff.id)) and not exists(select 1 from staff_subjects where staff_id=staff.id) limit 1;")
 if wrong: request('PARENT','/chat/messages',dict(scope,teacher_id=wrong,client_message_id=str(uuid.uuid4()),body='Forbidden'),403)
 same=str(uuid.uuid4())
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: a,b=list(pool.map(lambda _:send(same),range(2)))
 cid=a['conversation']['id']; ids.append(cid)
 assert a['message']['id']==b['message']['id'] and a['duplicate']!=b['duplicate']
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(lambda _:send(),range(2)))
 assert all(r['conversation']['id']==cid for r in results)
 assert sql(f"select count(*) from message_conversations where student_id='{STUDENT}' and type='parent_teacher';")=='1'
 message_id=a['message']['id']
 assert sql(f"select count(*) from messages where sender_id='{PARENT}' and client_message_id='{same}';")=='1'
 events_before=sql(f"select count(*) from notification_events where event_data->>'reference_id'='{cid}';")
 assert send(same)['message']['id']==message_id
 assert sql(f"select count(*) from notification_events where event_data->>'reference_id'='{cid}';")==events_before
 assert int(events_before)>0
 # The body-level key must reject collisions even when the HTTP header is absent.
 request('PARENT','/chat/messages',dict(scope,client_message_id=same,body='Changed body'),409)
 request('PARENT','/chat/messages',dict(scope,type='principal_parent',leader_id=LEADER,client_message_id=same,body='Synthetic atomic chat'),409)
 assert request('PARENT','/chat/messages',{'conversation_id':cid,'client_message_id':same,'body':'Synthetic atomic chat'})['message']['id']==message_id
 conflict=sql(f"select schooldesk_send_chat('{SCHOOL}','{PARENT}','{same}','Synthetic atomic chat','parent','Synthetic','{{\"id\":\"{uuid.uuid4()}\"}}','[]');",False)
 assert conflict.returncode and 'client_message_id was reused' in conflict.stderr
 assert sql(f"select count(*) from messages where sender_id='{PARENT}' and client_message_id='{same}';")=='1'
 assert sql(f"select count(*) from notification_events where event_data->>'reference_id'='{cid}';")==events_before
 print('PASS foreign child/class rejection, duplicate ack retry, body/context collision 409, explicit thread retry and concurrent first send')
 # Provoke a transactional failure after message insertion: no message or preview change survives.
 bad=str(uuid.uuid4()); before=sql(f"select last_message from message_conversations where id='{cid}';")
 failure=sql(f"select schooldesk_send_chat('{SCHOOL}','{PARENT}','{bad}','MUST ROLLBACK','parent','Synthetic','{{\"id\":\"{cid}\"}}','[{{\"id\":\"{uuid.uuid4()}\",\"role\":\"parent\",\"route\":\"/chat\"}}]');",False)
 assert failure.returncode and sql(f"select count(*) from messages where client_message_id='{bad}';")=='0'
 assert sql(f"select last_message from message_conversations where id='{cid}';")==before
 wrong_scope=sql(f"select schooldesk_send_chat('{SCHOOL}','{PARENT}','{uuid.uuid4()}','Forbidden direct RPC','parent','Synthetic','{{\"type\":\"parent_teacher\",\"teacher_id\":\"{TEACHER}\",\"parent_id\":\"{PARENT}\",\"student_id\":\"{foreign}\"}}','[]');",False)
 assert wrong_scope.returncode
 print('PASS transaction rollback includes message, preview and notices; direct RPC scope recheck')
 # More than one old page, including identical timestamps, exercises tuple cursors.
 sql(f"insert into messages(school_id,conversation_id,sender_id,body,sent_at,read_by) select '{SCHOOL}','{cid}','{PARENT}','Cursor '||g,'2026-10-17T00:00:00Z','[\"{PARENT}\"]' from generate_series(1,65) g;")
 latest=request('TEACHER',f'/chat/conversations/{cid}/messages?cursor_mode=latest&page_size=50')
 assert len(latest['data'])==50 and latest['has_more']
 assert latest['data'][-1]['id'] in [r['message']['id'] for r in [a]+results]
 cursor=latest['next_cursor']; older=request('TEACHER',f'/chat/conversations/{cid}/messages?cursor_mode=before&page_size=50&'+urllib.parse.urlencode({'cursor_sent_at':cursor['sent_at'],'cursor_id':cursor['id']}))
 assert len(older['data'])==18 and not older['has_more']
 assert len(set(r['id'] for r in latest['data']+older['data']))==68
 cursor=older['data'][-1]
 newer=request('TEACHER',f'/chat/conversations/{cid}/messages?cursor_mode=after&page_size=50&'+urllib.parse.urlencode({'cursor_sent_at':cursor['sent_at'],'cursor_id':cursor['id']}))
 assert [r['id'] for r in newer['data']]==[r['id'] for r in latest['data']]
 request('TEACHER',f'/chat/conversations/{cid}/messages?cursor_mode=before&cursor_id=invalid&cursor_sent_at=invalid',expected=400)
 baseline=request('TEACHER','/chat/unread-count')['unread_count']; assert baseline>=68
 boundary=older['data'][-1]
 request('TEACHER',f'/chat/conversations/{cid}/read',{'through_sent_at':boundary['sent_at'],'through_id':boundary['id']})
 assert request('TEACHER','/chat/unread-count')['unread_count']==baseline-18
 request('PRINCIPAL',f'/chat/conversations/{cid}/read',{})
 status=request('PARENT',f'/chat/conversations/{cid}/messages?cursor_mode=latest')
 assert not any(r['recipient_read'] for r in status['data'][-3:]),'Oversight receipt is not recipient receipt'
 request('TEACHER',f'/chat/conversations/{cid}/read',{})
 status=request('PARENT',f'/chat/conversations/{cid}/messages?cursor_mode=latest')
 assert all(r['recipient_read'] for r in status['data'])
 filtered=request('TEACHER','/chat/conversations?read_status=read&search=Chat%20Synthetic')
 assert any(r['id']==cid for r in filtered['data'])
 assert not any(r['id']==cid for r in request('TEACHER','/chat/conversations?read_status=unread&search=Chat%20Synthetic')['data'])
 request('SECOND_SCHOOL_PARENT',f'/chat/conversations/{cid}/messages?cursor_mode=latest',expected=404)
 before_many=request('TEACHER','/chat/unread-count')['unread_count']
 sql(f"insert into messages(school_id,conversation_id,sender_id,body,sent_at,read_by) select '{SCHOOL}','{cid}','{PARENT}','Aggregate '||g,'2026-10-17T01:00:00Z','[\"{PARENT}\"]' from generate_series(1,1100) g;")
 assert request('TEACHER','/chat/unread-count')['unread_count']==before_many+1100
 request('TEACHER',f'/chat/conversations/{cid}/read',{})
 assert request('TEACHER','/chat/unread-count')['unread_count']==before_many
 print('PASS latest/before/after tied cursors, bounded/legacy read, receipts, exact 1100-message aggregate, foreign school')
 # Another school leader's Direct thread is visible only through monitor, and cannot be sent by principal.
 sql(f"insert into staff(id,school_id,first_name,last_name,account_role) values('{CO_STAFF}','{SCHOOL}','Chat','Coordinator','coordinator'); insert into users(id,school_id,username,name,role_name,linked_id,is_active) values('{CO}','{SCHOOL}','chat-synthetic-{CO}','Chat Coordinator','coordinator','{CO_STAFF}',true);")
 direct=request('PARENT','/chat/messages',{'type':'principal_parent','parent_id':PARENT,'student_id':STUDENT,'leader_id':CO,'client_message_id':str(uuid.uuid4()),'body':'Leader private thread'})
 did=direct['conversation']['id'];ids.append(did)
 assert not any(r['id']==did for r in request('PRINCIPAL','/chat/conversations')['data'])
 assert any(r['id']==did for r in request('PRINCIPAL','/chat/monitor?page_size=100&search=Chat')['data'])
 request('PRINCIPAL','/chat/messages',{'conversation_id':did,'client_message_id':str(uuid.uuid4()),'body':'Wrong leader'},403)
 own=request('PRINCIPAL','/chat/messages',{'type':'principal_parent','parent_id':PARENT,'student_id':STUDENT,'client_message_id':str(uuid.uuid4()),'body':'Own direct thread'})
 assert any(r['id']==own['conversation']['id'] for r in request('PRINCIPAL','/chat/conversations')['data'])
 assert request('PRINCIPAL',f"/chat/conversations/{own['conversation']['id']}")['id']==own['conversation']['id']
 leader_message=request('PRINCIPAL','/chat/messages',{'conversation_id':cid,'client_message_id':str(uuid.uuid4()),'body':'Monitor reply to family and teacher'})['message']
 request('PARENT',f'/chat/conversations/{cid}/read',{})
 view=request('PRINCIPAL',f'/chat/conversations/{cid}/messages?cursor_mode=latest')['data']
 assert not next(m for m in view if m['id']==leader_message['id'])['recipient_read']
 request('TEACHER',f'/chat/conversations/{cid}/read',{})
 view=request('PRINCIPAL',f'/chat/conversations/{cid}/messages?cursor_mode=latest')['data']
 assert next(m for m in view if m['id']==leader_message['id'])['recipient_read']
 print('PASS leader-owned Direct, individual lookup, oversight monitor and both-recipient receipts')
 # Exercise the fourth role with a real seeded coordinator session.
 co_own=request('COORDINATOR','/chat/messages',{'type':'principal_parent','parent_id':PARENT,'student_id':STUDENT,'client_message_id':str(uuid.uuid4()),'body':'Coordinator own direct'})['conversation']['id']
 assert any(r['id']==co_own for r in request('COORDINATOR','/chat/conversations')['data'])
 assert not any(r['id']==co_own for r in request('PRINCIPAL','/chat/conversations')['data'])
 assert any(r['id']==co_own for r in request('PRINCIPAL','/chat/monitor?search=Chat')['data'])
 assert any(r['id']==cid for r in request('COORDINATOR','/chat/monitor?search=Chat')['data'])
 request('PRINCIPAL','/chat/messages',{'conversation_id':co_own,'client_message_id':str(uuid.uuid4()),'body':'Another leader direct'},403)
 request('TEACHER',f'/chat/conversations/{co_own}/messages?cursor_mode=latest',expected=403)
 request('SECOND_SCHOOL_COORDINATOR',f'/chat/conversations/{cid}/messages?cursor_mode=latest',expected=404)
 request('COORDINATOR','/chat/messages',{'conversation_id':cid,'client_message_id':str(uuid.uuid4()),'body':'Coordinator monitor reply'})
 request('PARENT','/chat/monitor',expected=403)
 request('TEACHER','/chat/monitor',expected=403)
 request('PARENT','/chat/contacts?role=principal',expected=403)
 print('PASS authenticated coordinator Direct/Monitor/send, role spoof rejection and cross-school leader isolation')
 # Avatar sanitization rejects arbitrary HTTP and another school's storage object.
 for unsafe in ['https://example.invalid/avatar.png',f'school-private-files/{uuid.uuid4()}/avatars/private.png']:
  sql(f"update users set avatar='{unsafe}' where id='{TEACHER_USER}';")
  contacts=request('PARENT',f'/chat/contacts?role=parent&student_id={STUDENT}')
  assert all(not c['avatar_url'] for c in contacts if c['id']==TEACHER)
 png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')
 for name in ['account.png','staff.png']:
  path=f'{SCHOOL}/chat-smoke/{STUDENT}/{name}';storage('POST',path,png);storage_paths.append(path)
 account_ref='school-private-files/'+storage_paths[0];staff_ref='school-private-files/'+storage_paths[1]
 sql(f"update users set avatar='{account_ref}' where id='{TEACHER_USER}';update staff set photo_url='{staff_ref}' where id='{TEACHER}';")
 contacts=request('PARENT',f'/chat/contacts?role=parent&student_id={STUDENT}')
 teacher_contact=next(c for c in contacts if c['id']==TEACHER)
 assert 'account.png' in teacher_contact['avatar_url'] and 'token=' in teacher_contact['avatar_url']
 parsed=urllib.parse.urlparse(teacher_contact['avatar_url'])
 with urllib.request.urlopen(CONFIG['SUPABASE_URL'].rstrip('/')+parsed.path+'?'+parsed.query,timeout=30) as image: assert image.read()==png
 # Sender and nested participant DTO use the same scoped account avatar.
 sent=request('TEACHER','/chat/messages',{'conversation_id':cid,'client_message_id':str(uuid.uuid4()),'body':'Photo sender'})
 assert 'account.png' in sent['message']['sender_avatar_url']
 assert 'account.png' in request('PARENT',f'/chat/conversations/{cid}')['teacher']['avatar_url']
 sql(f"update users set avatar=null where id='{TEACHER_USER}';")
 contacts=request('PARENT',f'/chat/contacts?role=parent&student_id={STUDENT}')
 assert 'staff.png' in next(c for c in contacts if c['id']==TEACHER)['avatar_url']
 sql(f"update staff set photo_url='school-private-files/{SCHOOL}/chat-smoke/{STUDENT}/missing.png' where id='{TEACHER}';")
 contacts=request('PARENT',f'/chat/contacts?role=parent&student_id={STUDENT}')
 assert not next(c for c in contacts if c['id']==TEACHER)['avatar_url']
 print('PASS privately signed account avatars, linked staff fallback, sender photos, missing/HTTP/foreign-school sanitization')
finally:
 for path in storage_paths: storage('DELETE',path)
 sql(f"delete from notification_events where event_data->>'reference_id' in (select id::text from message_conversations where student_id='{STUDENT}'); delete from notification_logs where reference_id in (select id::text from message_conversations where student_id='{STUDENT}'); delete from message_conversations where student_id='{STUDENT}'; delete from parent_student_links where student_id='{STUDENT}'; delete from students where id in ('{STUDENT}','{UNLINKED}'); delete from users where id='{CO}'; delete from staff where id='{CO_STAFF}'; update users set avatar={photo_restore} where id='{TEACHER_USER}';update staff set photo_url={staff_restore} where id='{TEACHER}';")

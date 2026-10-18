#!/usr/bin/env python3
"""Docker-only authenticated Realtime chat delivery and school isolation smoke."""
import json
import random
import subprocess
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / 'env.local.json').read_text())
API = CONFIG['API_BASE_URL'].rstrip('/')
assert urllib.parse.urlparse(API).hostname in ('localhost', '127.0.0.1', '::1'), 'Local API only'
assert urllib.parse.urlparse(CONFIG['SUPABASE_URL']).hostname in ('localhost', '127.0.0.1', '::1'), 'Local Realtime only'
SCHOOL = '00000000-0000-4000-8000-000000000001'
STUDENT = str(uuid.uuid4())
TRANSFER_SECTION = str(uuid.uuid4())
ASSIGNMENT = str(uuid.uuid4())
IP = f'198.18.{random.randrange(1,254)}.{random.randrange(1,254)}'
TOKENS = {}


def sql(statement):
    result = subprocess.run(['docker', '--context', 'default', 'exec', '-i', 'supabase_db_schooldesk-local', 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-Atq'], input=statement, text=True, capture_output=True, check=True)
    return result.stdout.strip()


def request(role, path, body):
    headers = {'Content-Type': 'application/json', 'x-forwarded-for': IP}
    if role:
        headers['Authorization'] = 'Bearer ' + TOKENS[role]
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), headers=headers)
    with urllib.request.urlopen(req, timeout=60) as response:
        value = json.loads(response.read())
        return value.get('data', value)


# Native Deno WebSocket implements the same Phoenix JSON join and database
# filters used by SupabaseChatWorkspaceRealtimeTransport. Tokens enter on stdin
# and are never written into evidence files or command arguments.
CLIENT = r'''
const c = JSON.parse(await new Response(Deno.stdin.readable).text());
const sockets = [];
const events = Object.fromEntries(c.subscribers.map(s => [s.label, []]));
let expected;
function assert(v, message) { if (!v) throw new Error(message); }
function channel(label, token, selected) {
  return new Promise((resolve, reject) => {
    const url = new URL(c.supabase + '/realtime/v1/websocket');
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    url.searchParams.set('apikey', c.anon); url.searchParams.set('vsn', '1.0.0');
    const ws = new WebSocket(url); sockets.push(ws);
    const topic = 'realtime:chat-workspace-smoke-' + label + '-' + crypto.randomUUID();
    let joined = false, replication = false;
    let bindings = [];
    const filters = [{event:'*',schema:'public',table:'message_conversations',filter:'school_id=eq.' + c.school}];
    if (selected) filters.push({event:'*',schema:'public',table:'messages',filter:'conversation_id=eq.' + c.conversation});
    const timeout = setTimeout(() => reject(new Error(label + ' subscription readiness timeout')), 30000);
    function ready() {
      if (!joined || !replication) return;
      clearTimeout(timeout);
      console.log('PASS authenticated ' + label + ' joined with ' + filters.length + ' Flutter-equivalent postgres filters');
      resolve(ws);
    }
    ws.onopen = () => ws.send(JSON.stringify({topic, event:'phx_join', ref:'1', join_ref:'1', payload:{config:{broadcast:{self:false},presence:{key:''},postgres_changes:filters},access_token:token}}));
    ws.onerror = () => reject(new Error(label + ' WebSocket transport error'));
    ws.onmessage = (message) => {
      const envelope = JSON.parse(message.data);
      if (envelope.event === 'phx_reply' && envelope.ref === '1') {
        if (envelope.payload.status !== 'ok') return reject(new Error(label + ' join rejected: ' + JSON.stringify(envelope.payload.response)));
        bindings = envelope.payload.response.postgres_changes ?? [];
        if (bindings.length !== filters.length) return reject(new Error(label + ' server omitted postgres filter bindings'));
        joined = true; ready();
      }
      if (envelope.event === 'system' && envelope.payload.extension === 'postgres_changes') {
        if (envelope.payload.status !== 'ok') return reject(new Error(label + ' replication rejected: ' + JSON.stringify(envelope.payload)));
        replication = true; ready();
      }
      if (envelope.event === 'postgres_changes') {
        const data = envelope.payload.data;
        const binding = bindings.find(b => b.table === data.table);
        assert(binding && envelope.payload.ids.includes(binding.id), label + ' callback subscription ID mismatch');
        events[label].push(data);
      }
    };
  });
}
let heartbeat;
try {
  await Promise.all(c.subscribers.map(s => channel(s.label, s.token, s.selected)));
  heartbeat = setInterval(() => sockets.forEach(ws => { if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify({topic:'phoenix',event:'heartbeat',payload:{},ref:String(Date.now())})); }), 10000);
  const sent = [];
  for (const [sender, body] of [['parent', 'Synthetic parent Realtime delivery'], ['teacher', 'Synthetic teacher Realtime reply']]) {
    const response = await fetch(c.api + '/chat/messages', {method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer ' + c[sender],'x-forwarded-for':c.ip},body:JSON.stringify({conversation_id:c.conversation,client_message_id:crypto.randomUUID(),body})});
    const payload = await response.json();
    assert(response.ok, sender + ' HTTP send failed: ' + response.status);
    expected = payload.data ?? payload;
    sent.push(expected.message.id);
    const deadline = Date.now() + 30000;
    function received() {
      return c.subscribers.filter(s => s.label !== 'foreign_teacher').every(s =>
        (!s.selected || events[s.label].some(e => e.table === 'messages' && e.type === 'INSERT' && e.record.id === expected.message.id && e.record.conversation_id === c.conversation && e.record.body === body))
        && events[s.label].some(e => e.table === 'message_conversations' && e.type === 'UPDATE' && e.record.id === c.conversation && e.record.last_message === body && e.record.last_sender_id === expected.message.sender_id));
    }
    while (!received() && Date.now() < deadline) await new Promise(r => setTimeout(r, 100));
    assert(received(), 'Missing matching callbacks after ' + sender + ' send: ' + JSON.stringify(events));
    console.log('PASS ' + sender + ' send: teacher/parent exact message INSERT + preview UPDATE; principal/coordinator school Monitor exact preview UPDATE');
  }
  async function sql(statement) {
    const child = new Deno.Command('docker', {args:['--context','default','exec','-i','supabase_db_schooldesk-local','psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-Atq'],stdin:'piped',stdout:'piped',stderr:'piped'}).spawn();
    const writer = child.stdin.getWriter(); await writer.write(new TextEncoder().encode(statement)); await writer.close();
    const output = await child.output();
    assert(output.success, 'Synthetic SQL action failed: ' + new TextDecoder().decode(output.stderr));
  }
  async function checkReads(role, allowed) {
    const http = await fetch(c.api + '/chat/conversations/' + c.conversation + '/messages?cursor_mode=latest', {headers:{Authorization:'Bearer ' + c[role],'x-forwarded-for':c.ip}});
    assert(http.status === (allowed ? 200 : 403), role + ' HTTP scope mismatch ' + http.status);
    for (const [table, filter] of [['message_conversations','id'],['messages','conversation_id']]) {
      const rest = await fetch(c.supabase + '/rest/v1/' + table + '?select=id&' + filter + '=eq.' + c.conversation, {headers:{apikey:c.anon,Authorization:'Bearer ' + c[role]}});
      const rows = await rest.json();
      assert(rest.ok && Array.isArray(rows) && (allowed ? rows.length > 0 : rows.length === 0), role + ' direct PostgREST scope mismatch for ' + table + ': ' + rest.status);
    }
  }
  async function probe(body, allowed, denied) {
    const id = crypto.randomUUID();
    await sql(`begin; insert into public.messages(id,school_id,conversation_id,sender_id,body,sent_at,delivered_at) values('${id}','${c.school}','${c.conversation}','${c.parent_user}','${body}',clock_timestamp(),clock_timestamp()); update public.message_conversations set last_message='${body}',last_sender_id='${c.parent_user}',last_message_at=clock_timestamp(),updated_at=clock_timestamp() where id='${c.conversation}'; commit;`);
    const deadline = Date.now() + 30000;
    function received() {
      return allowed.every(label => events[label].some(e => e.table === 'message_conversations' && e.type === 'UPDATE' && e.record.id === c.conversation && e.record.last_message === body)
        && (!['parent','teacher'].includes(label) || events[label].some(e => e.table === 'messages' && e.type === 'INSERT' && e.record.id === id)));
    }
    while (!received() && Date.now() < deadline) await new Promise(r => setTimeout(r,100));
    assert(received(), 'Allowed sockets missing synthetic revocation probe ' + body);
    await new Promise(r => setTimeout(r,3000));
    assert(!events[denied].some(e => e.record.id === id || e.table === 'message_conversations' && e.record.last_message === body), denied + ' received payload after scope revocation');
  }
  await checkReads('parent',true); await checkReads('teacher',true);
  await sql(`delete from public.parent_student_links where school_id='${c.school}' and parent_user_id='${c.parent_user}' and student_id='${c.student}';`);
  await checkReads('parent',false);
  await probe('Synthetic parent link revoked', ['teacher','principal_monitor','coordinator_monitor'], 'parent');
  console.log('PASS parent unlink: HTTP403, both PostgREST tables empty, existing socket denies new INSERT/preview UPDATE while authorized sockets receive');
  await sql(`insert into public.parent_student_links(school_id,parent_user_id,student_id) values('${c.school}','${c.parent_user}','${c.student}'); update public.students set current_section_id='${c.transfer_section}' where id='${c.student}';`);
  await checkReads('teacher',false); await checkReads('parent',true);
  await probe('Synthetic teacher scope transferred', ['parent','principal_monitor','coordinator_monitor'], 'teacher');
  console.log('PASS student transfer: teacher HTTP403, both PostgREST tables empty, existing socket denies new INSERT/preview UPDATE while authorized sockets receive');
  await sql(`update public.sections set co_teacher_id='${c.teacher_staff}' where id='${c.transfer_section}';`);
  await checkReads('teacher',true);
  await sql(`update public.sections set co_teacher_id=null where id='${c.transfer_section}'; insert into public.staff_subjects(id,school_id,staff_id,subject_id,section_id,grade_id,academic_year_id) select '${c.assignment}','${c.school}','${c.teacher_staff}','${c.subject}',id,grade_id,academic_year_id from public.sections where id='${c.transfer_section}';`);
  await checkReads('teacher',true);
  await sql(`update public.staff_subjects set section_id=null where id='${c.assignment}';`);
  await checkReads('teacher',true);
  console.log('PASS current co-teacher, section-subject and grade-subject scopes remain readable through HTTP and PostgREST');
  // Give the unauthorized subscriber the same delivery window after the valid
  // participant received both callbacks; it deliberately requested our scope.
  await new Promise(r => setTimeout(r, 3000));
  assert(events.foreign_teacher.length === 0, 'Foreign-school Realtime data leaked');
  console.log('PASS second-school teacher requesting identical filters received zero callbacks');
  console.log(JSON.stringify({message_ids:sent,conversation_id:c.conversation,callbacks:events,foreign_teacher_callback_count:events.foreign_teacher.length}));
} finally {
  clearInterval(heartbeat);
  for (const ws of sockets) if (ws.readyState === WebSocket.OPEN) ws.close();
}
'''

for role in ('PARENT', 'TEACHER', 'PRINCIPAL', 'COORDINATOR', 'SECOND_SCHOOL_TEACHER'):
    result = request(None, '/auth/login', {'username': CONFIG[f'QA_{role}_USERNAME'], 'password': CONFIG[f'QA_{role}_PASSWORD']})
    TOKENS[role] = result.get('access_token') or result['token']
fixture = json.loads(sql(f"select jsonb_build_object('parent',(select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_PARENT_USERNAME']}'),'teacher_user',(select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_TEACHER_USERNAME']}'),'teacher',(select linked_id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_TEACHER_USERNAME']}'));"))
parent, teacher = fixture['parent'], fixture['teacher']
section = sql(f"select id from sections where school_id='{SCHOOL}' and (class_teacher_id='{teacher}' or co_teacher_id='{teacher}') limit 1;")
assert section
catalog = sql("select jsonb_build_object('publication_tables',(select jsonb_agg(tablename order by tablename) from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in ('messages','message_conversations')),'rls_enabled',(select bool_and(relrowsecurity) from pg_class where oid in ('public.messages'::regclass,'public.message_conversations'::regclass)),'select_policies',(select jsonb_agg(policyname order by policyname) from pg_policies where schemaname='public' and tablename in ('messages','message_conversations') and cmd='SELECT')); ")
print('CATALOG ' + catalog, flush=True)
assert json.loads(catalog)['publication_tables'] == ['message_conversations', 'messages']
assert json.loads(catalog)['rls_enabled']
try:
    sql(f"insert into sections(id,school_id,grade_id,academic_year_id,section_name) select '{TRANSFER_SECTION}',school_id,grade_id,academic_year_id,'Realtime-{TRANSFER_SECTION[-8:]}' from sections where id='{section}'; insert into students(id,school_id,first_name,last_name,current_section_id) values('{STUDENT}','{SCHOOL}','Realtime','Synthetic','{section}'); insert into parent_student_links(school_id,parent_user_id,student_id) values('{SCHOOL}','{parent}','{STUDENT}');")
    initial = request('PARENT', '/chat/messages', {'type':'parent_teacher','teacher_id':teacher,'parent_id':parent,'student_id':STUDENT,'client_message_id':str(uuid.uuid4()),'body':'Synthetic Realtime setup'})
    config = {'api':API,'supabase':CONFIG['SUPABASE_URL'].rstrip('/'),'anon':CONFIG['SUPABASE_ANON_KEY'],'school':SCHOOL,'conversation':initial['conversation']['id'],'teacher':TOKENS['TEACHER'],'foreign':TOKENS['SECOND_SCHOOL_TEACHER'],'parent':TOKENS['PARENT'],'ip':IP}
    config.update({'student':STUDENT,'parent_user':parent,'teacher_user':fixture['teacher_user'],'teacher_staff':teacher,'transfer_section':TRANSFER_SECTION,'assignment':ASSIGNMENT,'subject':sql(f"select id from subjects where school_id='{SCHOOL}' limit 1;")})
    config['subscribers'] = [
        {'label': role.lower() + ('_monitor' if role in ('PRINCIPAL','COORDINATOR') else ''), 'token':TOKENS[role], 'selected':role in ('PARENT','TEACHER')}
        for role in ('PARENT','TEACHER','PRINCIPAL','COORDINATOR')
    ] + [{'label':'foreign_teacher','token':TOKENS['SECOND_SCHOOL_TEACHER'],'selected':True}]
    result = subprocess.run(['npx', '--yes', 'deno@2.5.6', 'eval', CLIENT], input=json.dumps(config), text=True, capture_output=True, timeout=240)
    print(result.stdout, end='', flush=True)
    if result.stderr:
        print(result.stderr, end='', flush=True)
    assert result.returncode == 0, f'Realtime subprocess exited {result.returncode}'
finally:
    sql(f"delete from notification_events where event_data->>'reference_id' in (select id::text from message_conversations where student_id='{STUDENT}'); delete from notification_logs where reference_id in (select id::text from message_conversations where student_id='{STUDENT}'); delete from message_conversations where student_id='{STUDENT}'; delete from parent_student_links where student_id='{STUDENT}'; delete from students where id='{STUDENT}'; delete from staff_subjects where id='{ASSIGNMENT}'; delete from sections where id='{TRANSFER_SECTION}';")
    print('PASS synthetic Realtime fixtures removed', flush=True)

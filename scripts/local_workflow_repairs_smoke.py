#!/usr/bin/env python3
"""Behavioral regression checks. Refuses every non-local API and DB target."""
import json
import random
import time
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / 'env.local.json').read_text())
API = CONFIG['API_BASE_URL'].rstrip('/')
assert urllib.parse.urlparse(API).hostname in ('localhost', '127.0.0.1', '::1'), 'Local synthetic API only'
SCHOOL = '00000000-0000-4000-8000-000000000001'
SECTION = '00000000-0000-4000-8000-000000000022'
STUDENT = '00000000-0000-4000-8000-000000000050'
YEAR = '00000000-0000-4000-8000-000000000010'
IP = f'198.18.{random.randrange(1,254)}.{random.randrange(1,254)}'
created_issues, created_reminders, created_sessions = [], [], []
CO_USER, CO_STAFF = str(uuid.uuid4()), str(uuid.uuid4())


def sql(statement):
    result = subprocess.run(['docker','exec','-i','supabase_db_schooldesk-local','psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-Atq'],input=statement,text=True,capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def request(role, path, body=None, method=None, expected=200):
    headers = {'Content-Type':'application/json','x-forwarded-for':IP}
    if role:
        headers['Authorization'] = 'Bearer '+TOKENS[role]
    req = urllib.request.Request(API+path, data=None if body is None else json.dumps(body).encode(), headers=headers,method=method or ('GET' if body is None else 'POST'))
    for attempt in range(4):
        try:
            response = urllib.request.urlopen(req,timeout=45)
        except urllib.error.HTTPError as error:
            response = error
        if response.status < 500 or (body is not None and path != '/auth/login') or attempt == 3:
            break
        response.close()
        time.sleep(1)
    with response:
        raw = response.read()
        payload = json.loads(raw) if raw else {}
        assert response.status == expected, f'{path}: {response.status}: {payload.get("error", "unexpected response")}'
        return payload.get('data',payload)


TOKENS = {}
for role in ['PARENT','PRINCIPAL','TEACHER','SUPER_ADMIN','SECOND_SCHOOL_PARENT','SECOND_SCHOOL_PRINCIPAL']:
    result = request(None,'/auth/login',{'username':CONFIG[f'QA_{role}_USERNAME'],'password':CONFIG[f'QA_{role}_PASSWORD']})
    TOKENS[role] = result.get('access_token') or result['token']

original = json.loads(sql(f"select jsonb_build_object('dob',(select date_of_birth from students where id='{STUDENT}'),'created_at',(select created_at from enrollments where student_id='{STUDENT}'),'co_teacher',(select co_teacher_id from sections where id='{SECTION}'));"))
try:
    # Parent creation previously violated the database role check.
    issue = request('PARENT','/issues',{'title':'Local parent workflow verification','description':'Synthetic local issue','category':'other'})
    created_issues.append(issue['id'])
    for status in ['pending,in_progress','resolved','']:
        rows = request('PARENT','/issues?status='+urllib.parse.quote(status))
        assert isinstance(rows['data'],list)
        if status != 'resolved': assert any(row['id']==issue['id'] for row in rows['data'])
    notice_count = sql(f"select count(*) from notification_logs where entity_id='{issue['id']}' and target_role='super_admin';")
    assert int(notice_count) == 1
    request('SUPER_ADMIN','/issues/'+issue['id'],{'status':'in_progress'},'PATCH')
    request('SUPER_ADMIN','/issues/'+issue['id'],{'status':'resolved','resolution_note':'Verified locally'},'PATCH')
    assert any(row['id']==issue['id'] for row in request('PARENT','/issues?status=resolved')['data'])
    request('SECOND_SCHOOL_PRINCIPAL','/issues/'+issue['id'],{'status':'resolved','resolution_note':'Forbidden'},'PATCH',403)
    print('PASS parent issue persistence, tabs, Super Admin routing and resolution')

    today = sql("select (now() at time zone 'Asia/Kolkata')::date;")
    sql(f"update students set date_of_birth=('2020-'||substring('{today}',6))::date where id='{STUDENT}'; update enrollments set created_at='2026-04-01T00:00:00Z' where student_id='{STUDENT}';")
    reminder = request('PARENT','/health-reminders',{'student_id':STUDENT,'reminder_date':today,'condition':'Local verification','notes':'Synthetic check'})
    created_reminders.append(reminder['id'])
    rows = request('PRINCIPAL','/notifications')['items']
    assert any(row['entity_id']==reminder['id'] for row in rows)
    principal_id = sql(f"select id from users where school_id='{SCHOOL}' and role_name='principal' limit 1;")
    sql(f"insert into notification_logs(school_id,user_id,target_role,title,type,entity_type,entity_id) select '{SCHOOL}','{principal_id}','principal','Newer local notice','general','local_test','page-'||g from generate_series(1,65) g;")
    for role in ['PRINCIPAL','TEACHER']:
        highlights = request(role,'/dashboard/highlights')['items']
        assert any(row['type']=='birthday' and row['student_id']==STUDENT for row in highlights)
        assert any(row['reference_id']==reminder['id'] for row in highlights)
    assert not any(row['id']==reminder['id'] for row in request('SECOND_SCHOOL_PARENT','/health-reminders'))
    foreign = sql(f"select id from students where school_id<>'{SCHOOL}' limit 1;")
    request('PARENT','/health-reminders?student_id='+foreign,expected=403)
    # Read operations must not erase the subject or clear unrelated unread rows.
    log = next(row for row in rows if row['entity_id']==reminder['id'])
    assert not log['is_read']
    request('PRINCIPAL','/notifications/'+log['id']+'/read',{},'PUT')
    assert any(row['id']==log['id'] and row['is_read'] for row in request('PRINCIPAL','/notifications?page_size=100')['items'])
    print('PASS health delivery, parent isolation, dated birthday and health highlights')

    homework = 'qa-homework-001'
    submission = request('PARENT',f'/homework/{homework}/submissions',{'student_id':STUDENT,'answer_text':'Parent comment stays separate','file_urls':[]})
    sid = submission['id']
    auth_columns = sql("select string_agg(quote_ident(column_name),',' order by ordinal_position) from information_schema.columns where table_schema='auth' and table_name='users' and is_generated='NEVER';")
    sql(f"""insert into staff select (jsonb_populate_record(null::staff,to_jsonb(s)||jsonb_build_object('id','{CO_STAFF}','staff_code','LOCAL-CO-REPAIR','email','local.co@synthetic.invalid'))).* from staff s where id='00000000-0000-4000-8000-000000000040';
      insert into auth.users ({auth_columns}) select {auth_columns} from (select (jsonb_populate_record(null::auth.users,to_jsonb(a)||jsonb_build_object('id','{CO_USER}','email','local.co@synthetic.invalid','phone',null,
        'raw_app_meta_data',jsonb_build_object('school_id','{SCHOOL}','role_name','teacher','linked_id','{CO_STAFF}')))).* from auth.users a join public.users u on u.id=a.id where u.school_id='{SCHOOL}' and u.role_name='teacher' limit 1) cloned;
      insert into public.users select (jsonb_populate_record(null::public.users,to_jsonb(u)||jsonb_build_object('id','{CO_USER}','username','local.co.repair','email','local.co@synthetic.invalid','linked_id','{CO_STAFF}'))).* from public.users u where u.school_id='{SCHOOL}' and u.role_name='teacher' limit 1;
      update sections set co_teacher_id='{CO_STAFF}' where id='{SECTION}';""")
    co_login = request(None,'/auth/login',{'username':'local.co.repair','password':CONFIG['QA_TEACHER_PASSWORD']})
    TOKENS['CO_TEACHER'] = co_login.get('access_token') or co_login['token']
    request('CO_TEACHER',f'/homework/{homework}/submissions/{sid}/review',{'status':'reviewed','remarks':'Reviewed successfully'},'PUT')
    retrieved = request('PARENT',f'/homework/{homework}/submissions?student_id={STUDENT}')['submissions']
    assert retrieved[0]['teacher_feedback']=='Reviewed successfully'
    assert retrieved[0]['status']=='reviewed'
    assert any(row['reference_id']==homework and row['body']=='Reviewed successfully' for row in request('PARENT','/notifications')['items'])
    request('SECOND_SCHOOL_PARENT',f'/homework/{homework}/submissions?student_id={STUDENT}',expected=404)
    print('PASS saved diary review, parent feedback retrieval and inbox delivery')

    previous = (date.fromisoformat(today)-timedelta(days=45)).isoformat()
    sql(f"""insert into students select (jsonb_populate_record(null::students,to_jsonb(s)||jsonb_build_object('id',gen_random_uuid(),'admission_number','LOCAL-ROSTER-'||g,'student_id_number','LOCAL-ROSTER-'||g))).* from students s cross join generate_series(1,120) g where s.id='{STUDENT}';
      update enrollments set created_at='2026-04-01T00:00:00Z' where school_id='{SCHOOL}' and academic_year_id='{YEAR}' and student_id in (select id from students where admission_number like 'LOCAL-ROSTER-%');""")
    roster = request('TEACHER',f'/attendance/roster?section_id={SECTION}&date={previous}')['items']
    assert len(roster) >= 121, 'Roster was truncated to a REST page'
    sql("delete from students where admission_number like 'LOCAL-ROSTER-%';")
    assert any(row['id']==STUDENT for row in roster)
    session = request('TEACHER','/attendance/sessions',{'section_id':SECTION,'academic_year_id':YEAR,'date':previous,'period_number':1})
    created_sessions.append(session['id'])
    enrollment = next(row['active_enrollment_id'] for row in roster if row['id']==STUDENT)
    request('TEACHER',f'/attendance/sessions/{session["id"]}/mark',{'attendances':[{'student_id':STUDENT,'enrollment_id':enrollment,'status':'present'}],'finalize':True})
    request('TEACHER',f'/attendance/sessions/{session["id"]}/mark',{'attendances':[{'student_id':STUDENT,'enrollment_id':enrollment,'status':'absent'}]},expected=409)
    sql(f"update student_attendances set enrollment_id=null where session_id='{session['id']}';")
    corrected_roster = request('TEACHER',f'/attendance/roster?section_id={SECTION}&date={previous}')['items']
    child_rows = [row for row in corrected_roster if row['id']==STUDENT]
    assert len(child_rows)==1 and child_rows[0]['active_enrollment_id']==enrollment, 'Saved legacy mark duplicated or lost dated enrollment'
    print('PASS legacy register membership deduplication')
    for invalid in ['2026-02-30','2026-03-31',(date.fromisoformat(today)+timedelta(days=1)).isoformat()]:
        request('TEACHER','/attendance/sessions',{'section_id':SECTION,'academic_year_id':YEAR,'date':invalid},expected=422)
    request('SECOND_SCHOOL_PRINCIPAL',f'/attendance/roster?section_id={SECTION}&date={previous}',expected=404)
    overview = request('PARENT','/dashboard/parent')['children'][0]
    assert 'attendance_today' in overview
    print('PASS >30-day attendance, current-year bounds, finalization and child overview DTO')

    # Fault injection proves workflow writes roll back when outbox persistence fails.
    sql("create function public.local_notice_failure() returns trigger language plpgsql as $$ begin raise exception 'Synthetic queue failure'; end $$; create trigger local_notice_failure before insert on notification_events for each row execute function public.local_notice_failure();")
    before = sql("select count(*) from issues;")
    request('PARENT','/issues',{'title':'Must roll back','description':'Queue unavailable'},expected=400)
    assert sql("select count(*) from issues;")==before
    sql('drop trigger local_notice_failure on notification_events; drop function public.local_notice_failure();')
    print('PASS atomic issue/outbox failure rollback')
finally:
    sql(f"delete from students where admission_number like 'LOCAL-ROSTER-%'; delete from notification_events where user_id='{CO_USER}'; delete from notification_logs where user_id='{CO_USER}' or entity_type='local_test'; update sections set co_teacher_id={repr(original['co_teacher']) if original['co_teacher'] else 'null'} where id='{SECTION}'; delete from public.users where id='{CO_USER}'; delete from auth.users where id='{CO_USER}'; delete from staff where id='{CO_STAFF}';")
    sql('drop trigger if exists local_notice_failure on notification_events; drop function if exists public.local_notice_failure();')
    sql(f"update students set date_of_birth={repr(original['dob']) if original['dob'] else 'null'} where id='{STUDENT}'; update enrollments set created_at='{original['created_at']}' where student_id='{STUDENT}';")
    for ident in created_issues:
        sql(f"delete from notification_events where event_data->>'reference_id'='{ident}'; delete from notification_logs where entity_id='{ident}'; delete from issues where id='{ident}';")
    for ident in created_reminders:
        sql(f"delete from notification_events where event_data->>'reference_id'='{ident}'; delete from notification_logs where entity_id='{ident}'; delete from health_reminders where id='{ident}';")
    for ident in created_sessions:
        sql(f"delete from attendance_sessions where id='{ident}';")

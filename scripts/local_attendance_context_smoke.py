#!/usr/bin/env python3
"""School-date context and teacher/co-teacher attendance; synthetic Docker only."""
import json
import random
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import date, timedelta
from pathlib import Path

CONFIG = json.loads((Path(__file__).resolve().parent.parent / 'env.local.json').read_text())
API = CONFIG['API_BASE_URL'].rstrip('/')
assert urllib.parse.urlparse(API).hostname in ('localhost', '127.0.0.1', '::1')
SCHOOL = '00000000-0000-4000-8000-000000000001'
BASE_SECTION = '00000000-0000-4000-8000-000000000022'
YEAR = '00000000-0000-4000-8000-000000000010'
SECTION, STUDENT, CO_STAFF, CO_USER = [str(uuid.uuid4()) for _ in range(4)]
PREFIX = 'context-' + uuid.uuid4().hex[:10]
IP = f'198.18.{random.randrange(1,254)}.{random.randrange(1,254)}'
TOKENS = {}

def sql(statement):
    result = subprocess.run(['docker', '--context', 'default', 'exec', '-i', 'supabase_db_schooldesk-local', 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-Atq'], input=statement, text=True, capture_output=True)
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()

def request(role, path, body=None, expected=200):
    headers = {'Content-Type': 'application/json', 'x-forwarded-for': IP}
    if role: headers['Authorization'] = 'Bearer ' + TOKENS[role]
    req = urllib.request.Request(API + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
    try: response = urllib.request.urlopen(req, timeout=60)
    except urllib.error.HTTPError as error: response = error
    with response:
        value = json.load(response)
        assert response.status == expected, (path, response.status, value.get('error'))
        return value.get('data', value)

for role in ['PRINCIPAL', 'PARENT', 'TEACHER', 'SECOND_SCHOOL_TEACHER']:
    result = request(None, '/auth/login', {'username': CONFIG[f'QA_{role}_USERNAME'], 'password': CONFIG[f'QA_{role}_PASSWORD']})
    TOKENS[role] = result.get('access_token') or result['token']
parent = sql(f"select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_PARENT_USERNAME']}';")
teacher = sql(f"select linked_id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_TEACHER_USERNAME']}';")
original = json.loads(sql(f"select to_jsonb(y) from academic_years y where id='{YEAR}';"))
today = sql(f"select (now() at time zone timezone)::date from schools where id='{SCHOOL}';")
previous = (date.fromisoformat(today) - timedelta(days=1)).isoformat()

try:
    auth_columns = sql("select string_agg(quote_ident(column_name),',' order by ordinal_position) from information_schema.columns where table_schema='auth' and table_name='users' and is_generated='NEVER';")
    sql(f"""insert into staff select (jsonb_populate_record(null::staff,to_jsonb(s)||jsonb_build_object('id','{CO_STAFF}','staff_code','{PREFIX}','email','{PREFIX}@synthetic.invalid'))).* from staff s where id='{teacher}';
      insert into auth.users ({auth_columns}) select {auth_columns} from (select (jsonb_populate_record(null::auth.users,to_jsonb(a)||jsonb_build_object('id','{CO_USER}','email','{PREFIX}@synthetic.invalid','phone',null,
        'raw_app_meta_data',jsonb_build_object('school_id','{SCHOOL}','role_name','teacher','linked_id','{CO_STAFF}')))).* from auth.users a join public.users u on u.id=a.id where u.school_id='{SCHOOL}' and u.role_name='teacher' limit 1) cloned;
      insert into public.users select (jsonb_populate_record(null::public.users,to_jsonb(u)||jsonb_build_object('id','{CO_USER}','username','{PREFIX}','email','{PREFIX}@synthetic.invalid','linked_id','{CO_STAFF}'))).* from public.users u where u.school_id='{SCHOOL}' and u.role_name='teacher' limit 1;
      insert into sections(id,school_id,grade_id,academic_year_id,section_name,class_teacher_id,co_teacher_id)
      select '{SECTION}',school_id,grade_id,academic_year_id,'{PREFIX}','{teacher}','{CO_STAFF}' from sections where id='{BASE_SECTION}';""")
    result = request(None, '/auth/login', {'username': PREFIX, 'password': CONFIG['QA_TEACHER_PASSWORD']})
    TOKENS['CO_TEACHER'] = result.get('access_token') or result['token']
    request('PRINCIPAL', '/students', {'id': STUDENT, 'first_name': PREFIX, 'last_name': 'Learner', 'status': 'active', 'current_section_id': SECTION, 'parent_user_id': parent, 'admission_date': previous, 'is_test_account': True})
    for role in ['TEACHER', 'CO_TEACHER']:
        context = request(role, '/attendance/context?section_id=' + SECTION)
        assert context['school_date'] == today and context['configuration_status'] == 'ready'
        assert context['academic_year_id'] == YEAR and context['max_date'] == today
        roster = request(role, f'/attendance/roster?section_id={SECTION}&date={today}')['items']
        assert len(roster) == 1 and roster[0]['id'] == STUDENT and roster[0]['active_enrollment_id']
    request('PARENT', '/attendance/context?section_id=' + SECTION, expected=403)
    request('SECOND_SCHOOL_TEACHER', '/attendance/context?section_id=' + SECTION, expected=403)
    request('TEACHER', '/attendance/context?section_id=invalid', expected=422)
    print('PASS class/co-teacher context, school date, enrollment roster and parent/foreign-class denial', flush=True)

    sql(f"update academic_years set end_date='{previous}' where id='{YEAR}';")
    context = request('TEACHER', '/attendance/context?section_id=' + SECTION)
    assert context['configuration_status'] == 'ended' and context['max_date'] == previous
    assert request('CO_TEACHER', f'/attendance/roster?section_id={SECTION}&date={previous}')['items']
    request('TEACHER', f'/attendance/roster?section_id={SECTION}&date={today}', expected=422)
    future = (date.fromisoformat(today) + timedelta(days=1)).isoformat()
    sql(f"update academic_years set start_date='{future}',end_date='{original['end_date']}' where id='{YEAR}';")
    context = request('CO_TEACHER', '/attendance/context?section_id=' + SECTION)
    assert context['configuration_status'] == 'not_started' and context['min_date'] is None and context['max_date'] is None
    sql(f"update academic_years set start_date='{original['start_date']}',end_date='{original['end_date']}',is_current=false where id='{YEAR}';")
    assert request('TEACHER', '/attendance/context?section_id=' + SECTION)['configuration_status'] == 'invalid_year'
    sql(f"update academic_years set is_current=true where id='{YEAR}';")
    assert request('TEACHER', '/attendance/context?section_id=' + SECTION)['configuration_status'] == 'ready'
    print('PASS ended/future/noncurrent year context, bounded history and recovery after leadership correction', flush=True)

    for role, attendance_date in [('TEACHER', previous), ('CO_TEACHER', today)]:
        roster = request(role, f'/attendance/roster?section_id={SECTION}&date={attendance_date}')['items']
        session = request(role, '/attendance/sessions', {'section_id': SECTION, 'academic_year_id': YEAR, 'date': attendance_date, 'period_number': 1})
        mark = {'student_id': STUDENT, 'enrollment_id': roster[0]['active_enrollment_id'], 'status': 'present'}
        request(role, f"/attendance/sessions/{session['id']}/mark", {'attendances': [mark], 'finalize': False})
        other = 'CO_TEACHER' if role == 'TEACHER' else 'TEACHER'
        request(other, f"/attendance/sessions/{session['id']}/mark", {'attendances': [mark], 'finalize': False}, expected=403)
        request(role, f"/attendance/sessions/{session['id']}/mark", {'attendances': [mark], 'finalize': True})
        request(role, f"/attendance/sessions/{session['id']}/mark", {'attendances': [mark], 'finalize': False}, expected=409)
        assert sql(f"select count(*) from student_attendances where session_id='{session['id']}' and student_id='{STUDENT}' and enrollment_id='{roster[0]['active_enrollment_id']}' and status='present';") == '1'
    request('TEACHER', '/attendance/sessions', {'section_id': SECTION, 'academic_year_id': YEAR, 'date': future}, expected=422)
    request('CO_TEACHER', '/attendance/sessions', {'section_id': SECTION, 'academic_year_id': YEAR, 'date': '2026-02-30'}, expected=422)
    print('PASS teacher and co-teacher historical/current draft and final saves, exact enrollment, competing claim/finalized protection and future/invalid-date rejection', flush=True)
finally:
    sql(f"update academic_years set start_date='{original['start_date']}',end_date='{original['end_date']}',is_current={'true' if original['is_current'] else 'false'} where id='{YEAR}';")
    sql(f"delete from attendance_sessions where section_id='{SECTION}'; delete from class_daily_operation_claims where section_id='{SECTION}'; delete from fee_invoices where student_id='{STUDENT}'; delete from students where id='{STUDENT}'; delete from sections where id='{SECTION}'; delete from notification_events where user_id='{CO_USER}'; delete from notification_logs where user_id='{CO_USER}'; delete from public.users where id='{CO_USER}'; delete from auth.users where id='{CO_USER}'; delete from staff where id='{CO_STAFF}';")
    print('PASS synthetic context/attendance fixtures removed', flush=True)

#!/usr/bin/env python3
"""Selected-branch notification and initial enrollment regression, synthetic Docker only."""
import concurrent.futures
import json
import random
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / 'env.local.json').read_text())
API = CONFIG['API_BASE_URL'].rstrip('/')
assert urllib.parse.urlparse(API).hostname in ('localhost', '127.0.0.1', '::1'), 'Synthetic local API only'
DB = 'supabase_db_schooldesk-local'
SCHOOL = '00000000-0000-4000-8000-000000000001'
SECTION = '00000000-0000-4000-8000-000000000022'
YEAR = '00000000-0000-4000-8000-000000000010'
BRANCH, FOREIGN, RECIPIENT, NEXT_SECTION = [str(uuid.uuid4()) for _ in range(4)]
PREFIX = 'branch-enrollment-' + uuid.uuid4().hex[:8]
IP = f'198.18.{random.randrange(1,254)}.{random.randrange(1,254)}'
TOKENS, STUDENTS, BROADCASTS = {}, [], []


def sql(statement, expected_error=None):
    p = subprocess.run(['docker', '--context', 'default', 'exec', '-i', DB, 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-Atq'], input=statement, text=True, capture_output=True)
    if expected_error:
        assert p.returncode and expected_error in p.stderr, p.stderr
        return p.stderr
    assert p.returncode == 0, p.stderr
    return p.stdout.strip()


def request(role, path, body=None, method=None, expected=200, branch=None, key=None):
    headers = {'Content-Type': 'application/json', 'x-forwarded-for': IP}
    if role: headers['Authorization'] = 'Bearer ' + TOKENS[role]
    if branch: headers['x-schooldesk-branch-id'] = branch
    if key: headers['Idempotency-Key'] = key
    req = urllib.request.Request(API + path, data=None if body is None else json.dumps(body).encode(), headers=headers, method=method or ('GET' if body is None else 'POST'))
    for attempt in range(5):
        try: response = urllib.request.urlopen(req, timeout=60)
        except urllib.error.HTTPError as error: response = error
        with response:
            payload = json.load(response)
            if response.status == 409 and expected == 200 and 'still processing' in str(payload.get('error', '')) and attempt < 4:
                time.sleep(1)
                continue
            assert response.status == expected, (path, response.status, payload.get('error'))
            return payload.get('data', payload)


for role in ['PRINCIPAL', 'PARENT', 'TEACHER', 'COORDINATOR', 'SUPER_ADMIN']:
    login = request(None, '/auth/login', {'username': CONFIG[f'QA_{role}_USERNAME'], 'password': CONFIG[f'QA_{role}_PASSWORD']})
    TOKENS[role] = login.get('access_token') or login['token']
PRINCIPAL = sql(f"select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_PRINCIPAL_USERNAME']}';")
PARENT = sql(f"select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_PARENT_USERNAME']}';")
ORIGINAL_PRINCIPAL = json.loads(sql(f"select jsonb_build_object('role',role_name,'active',is_active) from users where id='{PRINCIPAL}';"))
DATES = json.loads(sql(f"select jsonb_build_object('today',(now() at time zone s.timezone)::date,'admitted',greatest(a.start_date,(now() at time zone s.timezone)::date-7),'start',a.start_date) from academic_years a join schools s on s.id=a.school_id where a.id='{YEAR}';"))

try:
    sql(f"""insert into schools(id,name,organization_id) select '{BRANCH}','{PREFIX} branch',organization_id from schools where id='{SCHOOL}';
      insert into organizations(id,name) values('{FOREIGN}','{PREFIX} foreign org');
      insert into schools(id,name,organization_id) values('{FOREIGN}','{PREFIX} foreign','{FOREIGN}');
      insert into users(id,school_id,name,username,role_name,is_active) values('{RECIPIENT}','{BRANCH}','Branch recipient','{PREFIX}.parent','parent',true);
      insert into sections(id,school_id,grade_id,academic_year_id,section_name) select '{NEXT_SECTION}',school_id,grade_id,academic_year_id,'{PREFIX}' from sections where id='{SECTION}';""")
    assert request('PRINCIPAL', '/notifications/recipients?roles=parent')['total'] >= 1
    recipients = request('PRINCIPAL', '/notifications/recipients?roles=parent', branch=BRANCH)
    assert [r['id'] for r in recipients['items']] == [RECIPIENT]
    body = {'title': PREFIX, 'message': 'Selected branch only', 'roles': ['parent'], 'mode': 'selected', 'user_ids': [RECIPIENT]}
    key = str(uuid.uuid4())
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(lambda _: request('PRINCIPAL', '/notifications/broadcasts', body, branch=BRANCH, key=key), range(3)))
    bid = results[0]['id']; BROADCASTS.append(bid)
    assert len({r['id'] for r in results}) == 1 and all(r['recipient_count'] == 1 for r in results)
    assert sql(f"select count(*) from notification_logs where entity_type='notification_broadcast' and entity_id='{bid}' and school_id='{BRANCH}' and user_id='{RECIPIENT}';") == '1'
    assert sql(f"select count(*) from notification_events where event_type='custom_notification' and event_data->>'reference_id'='{bid}';") == '1'
    assert any(r['id'] == bid for r in request('PRINCIPAL', '/notifications/broadcasts', branch=BRANCH)['items'])
    assert all(r['id'] != bid for r in request('PRINCIPAL', '/notifications/broadcasts')['items'])
    request('PRINCIPAL', '/notifications/broadcasts', {**body, 'message': 'Different'}, branch=BRANCH, key=key, expected=409)
    request('PRINCIPAL', '/notifications/broadcasts', {**body, 'user_ids': [PARENT]}, branch=BRANCH, key=str(uuid.uuid4()), expected=422)
    # Existing JWT remains principal; live SQL must reject changed membership role.
    sql(f"update branch_memberships set role_name='teacher' where user_id='{PRINCIPAL}' and school_id='{BRANCH}';")
    request('PRINCIPAL', '/notifications/recipients?roles=parent', branch=BRANCH, expected=403)
    request('PRINCIPAL', '/notifications/broadcasts', branch=BRANCH, expected=403)
    request('PRINCIPAL', '/notifications/broadcasts', body, branch=BRANCH, key=key, expected=403)
    sql(f"update branch_memberships set role_name='principal',is_active=false where user_id='{PRINCIPAL}' and school_id='{BRANCH}';")
    assert sql(f"select notification_principal_has_branch_access('{BRANCH}','{PRINCIPAL}');") == 'f'
    request('PRINCIPAL', '/notifications/recipients?roles=parent', branch=BRANCH, expected=401)
    sql(f"insert into branch_memberships(user_id,school_id,role_name) values('{PRINCIPAL}','{FOREIGN}','principal');")
    request('PRINCIPAL', '/notifications/recipients?roles=parent', branch=FOREIGN, expected=403)
    sql(f"update users set role_name='teacher' where id='{PRINCIPAL}';")
    request('PRINCIPAL', '/notifications/recipients?roles=parent', expected=403)
    sql(f"update users set role_name='principal',is_active=false where id='{PRINCIPAL}';")
    assert sql(f"select notification_principal_has_branch_access('{SCHOOL}','{PRINCIPAL}');") == 'f'
    sql(f"update users set is_active=true where id='{PRINCIPAL}';")
    for role in ['PARENT', 'TEACHER', 'COORDINATOR', 'SUPER_ADMIN']:
        request(role, '/notifications/recipients?roles=parent', expected=403)
    print('PASS branch principal, home principal, revoked/wrong-role/foreign-org/inactive/downgraded guards, scoped recipients/history, concurrent retry and fanout', flush=True)

    def create_student(**changes):
        sid = str(uuid.uuid4()); STUDENTS.append(sid)
        payload = {'id': sid, 'first_name': PREFIX, 'last_name': 'Learner', 'status': 'active', 'current_section_id': SECTION, 'parent_user_id': PARENT, 'admission_date': DATES['admitted'], 'is_test_account': True, **changes}
        row = request('PRINCIPAL', '/students', payload)
        assert row['id'] == sid
        return sid

    def enrollment(sid):
        return json.loads(sql(f"select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'school',e.school_id,'year',e.academic_year_id,'section',e.section_id,'effective',(e.created_at at time zone s.timezone)::date,'at',e.created_at)),'[]') from enrollments e join schools s on s.id=e.school_id where student_id='{sid}';"))

    sid = create_student()
    initial = enrollment(sid)
    assert len(initial) == 1 and initial[0]['effective'] == DATES['admitted'] and initial[0]['school'] == SCHOOL and initial[0]['year'] == YEAR and initial[0]['section'] == SECTION
    request('PRINCIPAL', '/students/' + sid, {'status': 'active', 'current_section_id': SECTION}, 'PATCH')
    assert enrollment(sid) == initial
    request('PRINCIPAL', '/students/' + sid, {'current_section_id': NEXT_SECTION}, 'PATCH')
    assert enrollment(sid) == initial, 'Transfer history must remain untouched'
    undated = create_student(admission_date=None)
    assert enrollment(undated)[0]['effective'] == DATES['today']
    earlier = create_student(admission_date='2020-01-01')
    assert enrollment(earlier)[0]['effective'] == DATES['start']
    later = create_student(status='pending', current_section_id=None, admission_date='2020-01-01')
    assert enrollment(later) == []
    request('PRINCIPAL', '/students/' + later, {'status': 'active', 'current_section_id': SECTION}, 'PATCH')
    assert enrollment(later)[0]['effective'] == DATES['today']
    # An existing dated record must survive a later activation or section change.
    request('PRINCIPAL', '/students/' + later, {'status': 'inactive'}, 'PATCH')
    dated = enrollment(later)
    request('PRINCIPAL', '/students/' + later, {'status': 'active', 'current_section_id': NEXT_SECTION}, 'PATCH')
    assert enrollment(later) == dated
    # Invalid assignment and an injected enrollment failure must roll back student writes.
    bad = str(uuid.uuid4()); STUDENTS.append(bad)
    foreign_section = sql(f"select id from sections where school_id<>'{SCHOOL}' limit 1;")
    sql(f"insert into students(id,school_id,first_name,last_name,current_section_id) values('{bad}','{SCHOOL}','{PREFIX}','Invalid','{foreign_section}');", 'Initial active class assignment requires')
    assert sql(f"select count(*) from students where id='{bad}';") == '0'
    invalid_year = str(uuid.uuid4()); STUDENTS.append(invalid_year)
    sql(f"begin; update academic_years set is_current=false where id='{YEAR}'; insert into students(id,school_id,first_name,last_name,current_section_id) values('{invalid_year}','{SCHOOL}','{PREFIX}','Invalid year','{SECTION}');", 'Initial active class assignment requires')
    assert sql(f"select count(*) from students where id='{invalid_year}';") == '0'
    assert sql(f"select is_current from academic_years where id='{YEAR}';") == 't'
    # Year configuration must not prevent an ordinary save of an existing learner.
    sql(f"begin; update academic_years set is_current=false where id='{YEAR}'; update students set current_section_id=current_section_id where id='{sid}'; rollback;")
    sql("create function public.local_initial_enrollment_failure() returns trigger language plpgsql as $$ begin raise exception 'Synthetic enrollment failure'; end $$; create trigger local_initial_enrollment_failure before insert on enrollments for each row execute function public.local_initial_enrollment_failure();")
    failed = str(uuid.uuid4()); STUDENTS.append(failed)
    request('PRINCIPAL', '/students', {'id': failed, 'first_name': PREFIX, 'last_name': 'Rollback', 'status': 'active', 'current_section_id': SECTION, 'parent_user_id': PARENT}, expected=400)
    assert sql(f"select count(*) from students where id='{failed}';") == '0'
    sql('drop trigger local_initial_enrollment_failure on enrollments; drop function public.local_initial_enrollment_failure();')
    # Auckland midnight is the previous calendar day in Kolkata. The roster must
    # exclude the learner the day before admission and include the admission day.
    zone_student = str(uuid.uuid4())
    sql(f"""begin;
      update schools set timezone='Pacific/Auckland' where id='{SCHOOL}';
      insert into students(id,school_id,first_name,last_name,admission_date,current_section_id,status)
        values('{zone_student}','{SCHOOL}','{PREFIX}','Timezone','{DATES['today']}','{SECTION}','active');
      do $$ begin
        if exists(select 1 from jsonb_array_elements(public.attendance_roster('{SCHOOL}','{SECTION}','{YEAR}','{DATES['today']}'::date-1)->'items') r where r->>'id'='{zone_student}') then
          raise exception 'Learner appeared before school local admission date';
        end if;
        if not exists(select 1 from jsonb_array_elements(public.attendance_roster('{SCHOOL}','{SECTION}','{YEAR}','{DATES['today']}')->'items') r where r->>'id'='{zone_student}') then
          raise exception 'Learner missing on school local admission date';
        end if;
      end $$;
      rollback;""")
    print('PASS API initial enrollment, dated/undated admissions, year-start clamp, today activation, duplicate saves, transfer preservation, scope validation, school-timezone roster boundary and atomic rollback', flush=True)
finally:
    sql('drop trigger if exists local_initial_enrollment_failure on enrollments; drop function if exists public.local_initial_enrollment_failure();')
    sql(f"update users set role_name='{ORIGINAL_PRINCIPAL['role']}',is_active={'true' if ORIGINAL_PRINCIPAL['active'] else 'false'} where id='{PRINCIPAL}';")
    if STUDENTS:
        ids = ','.join("'" + i + "'" for i in STUDENTS)
        sql(f"delete from fee_invoices where student_id in ({ids}); delete from students where id in ({ids});")
    sql(f"delete from sections where id='{NEXT_SECTION}'; delete from notification_events where school_id in ('{BRANCH}','{FOREIGN}'); delete from notification_logs where school_id in ('{BRANCH}','{FOREIGN}'); delete from notification_broadcasts where school_id in ('{BRANCH}','{FOREIGN}'); delete from users where id='{RECIPIENT}'; delete from schools where id in ('{BRANCH}','{FOREIGN}'); delete from organizations where id='{FOREIGN}';")

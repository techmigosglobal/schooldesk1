#!/usr/bin/env python3
"""Authenticated, synthetic Docker-local attendance correction regression tests."""
import json
import os
from pathlib import Path
import random
import subprocess
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / 'env.local.json').read_text())
API = CONFIG['API_BASE_URL'].rstrip('/')
parsed = urllib.parse.urlparse(API)
if parsed.hostname not in ('127.0.0.1', 'localhost', '::1'):
    raise SystemExit('Refusing to test attendance mutations against a non-local API')
CONTAINER = 'supabase_db_schooldesk-local'
DOCKER = ['docker']
if not os.environ.get('DOCKER_CONTEXT') and not os.environ.get('DOCKER_HOST'):
    if subprocess.run(DOCKER + ['exec', CONTAINER, 'true'], capture_output=True).returncode:
        DOCKER += ['--context', 'default']
uid = lambda value: f'00000000-0000-4000-8000-{value:012d}'
SCHOOL, SECTION, OTHER_SECTION = uid(1), uid(661), uid(662)
SESSION, OTHER_SESSION, STUDENT = uid(663), uid(664), uid(665)
client_ip = f'198.18.{random.randrange(1, 254)}.{random.randrange(1, 254)}'


def sql(statement):
    result = subprocess.run(
        DOCKER + ['exec', '-i', CONTAINER, 'psql', '-X', '-U', 'postgres',
         '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-Atq'],
        input=statement, text=True, capture_output=True,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def request(path, body, token=None):
    headers = {'Content-Type': 'application/json', 'x-forwarded-for': client_ip}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), headers=headers)
    try:
        response = urllib.request.urlopen(req, timeout=30)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status, json.loads(response.read())


def login(role):
    status, body = request('/auth/login', {
        'username': CONFIG[f'QA_{role}_USERNAME'],
        'password': CONFIG[f'QA_{role}_PASSWORD'],
    })
    assert status == 200, f'{role} local login failed ({status})'
    return body['data'].get('access_token') or body['data']['token']


def snapshot():
    return json.loads(sql(f"""select jsonb_build_object(
      'sessions', (select jsonb_agg(to_jsonb(a) order by id) from attendance_sessions a
                   where id in ('{SESSION}', '{OTHER_SESSION}')),
      'claims', (select coalesce(jsonb_agg(to_jsonb(c) order by id), '[]'::jsonb)
                 from class_daily_operation_claims c where section_id in ('{SECTION}', '{OTHER_SECTION}')),
      'marks', (select jsonb_agg(to_jsonb(a) order by id) from student_attendances a where student_id='{STUDENT}')
    );"""))


def cleanup():
    sql(f"""drop trigger if exists attendance_reopen_smoke_failure on class_daily_operation_claims;
      drop function if exists public.attendance_reopen_smoke_failure();
      delete from student_attendances where student_id='{STUDENT}';
      delete from attendance_sessions where id in ('{SESSION}', '{OTHER_SESSION}');
      delete from students where id='{STUDENT}';
      delete from sections where id in ('{SECTION}', '{OTHER_SECTION}');""")


try:
    cleanup()
    sql(f"""begin;
      insert into sections select (jsonb_populate_record(null::sections,
        to_jsonb(s) || jsonb_build_object('id', '{SECTION}', 'section_name', 'Reopen target'))).*
        from sections s where id='{uid(22)}';
      insert into sections select (jsonb_populate_record(null::sections,
        to_jsonb(s) || jsonb_build_object('id', '{OTHER_SECTION}', 'section_name', 'Reopen other'))).*
        from sections s where id='{uid(22)}';
      insert into attendance_sessions select (jsonb_populate_record(null::attendance_sessions,
        to_jsonb(s) || jsonb_build_object('id', '{SESSION}', 'section_id', '{SECTION}',
          'status', 'needs_review', 'is_finalized', true, 'reopen_history', '[]'::jsonb))).*
        from attendance_sessions s where id='{uid(60)}';
      insert into attendance_sessions select (jsonb_populate_record(null::attendance_sessions,
        to_jsonb(s) || jsonb_build_object('id', '{OTHER_SESSION}', 'section_id', '{OTHER_SECTION}',
          'status', 'submitted', 'is_finalized', true, 'reopen_history', '[]'::jsonb))).*
        from attendance_sessions s where id='{uid(60)}';
      insert into students select (jsonb_populate_record(null::students,
        to_jsonb(s) || jsonb_build_object('id', '{STUDENT}', 'current_section_id', '{OTHER_SECTION}',
          'admission_number', 'LOCAL-REOPEN', 'student_id_number', 'LOCAL-REOPEN'))).*
        from students s where id='{uid(50)}';
      insert into student_attendances(session_id, student_id, status)
        values ('{SESSION}', '{STUDENT}', 'absent');
      commit;""")
    date = sql(f"select date from attendance_sessions where id='{SESSION}';")
    foreign_student = sql(f"select id from students where school_id<>'{SCHOOL}' limit 1;")
    principal, teacher, second_principal = login('PRINCIPAL'), login('TEACHER'), login('SECOND_SCHOOL_PRINCIPAL')
    path = f'/attendance/sessions/{SESSION}/reopen'
    payload = {'section_id': SECTION, 'date': date, 'student_id': STUDENT,
               'reason': 'Synthetic correction regression test'}
    before = snapshot()

    def rejected(label, expected, body, token=principal, route=path):
        status, _ = request(route, body, token)
        assert status == expected, f'{label}: expected {expected}, received {status}'
        assert snapshot() == before, f'{label}: rejected request changed attendance'
        print(f'PASS: {label} ({status}), no mutation')

    rejected('legacy reason-only request', 409, {'reason': 'ok'})
    rejected('wrong class', 409, {**payload, 'section_id': OTHER_SECTION})
    rejected('wrong date', 409, {**payload, 'date': '2000-01-01'})
    rejected('wrong student / foreign school', 409, {**payload, 'student_id': foreign_student})
    rejected('different school principal', 404, payload, second_principal)
    rejected('teacher cannot reopen registers', 403, payload, teacher)
    rejected('empty reason', 400, {**payload, 'reason': '   '})
    rejected('invalid date', 400, {**payload, 'date': '2026-02-30'})
    rejected('missing session', 404, payload, route=f'/attendance/sessions/{uid(9999)}/reopen')

    # Force a failure in claim synchronization and prove the session/history
    # remain unchanged. This trigger exists only in the synthetic local stack.
    sql(f"""create function public.attendance_reopen_smoke_failure() returns trigger
      language plpgsql as $$ begin
        if new.section_id='{SECTION}' then raise exception 'synthetic claim failure'; end if;
        return new; end $$;
      create trigger attendance_reopen_smoke_failure before insert or update
      on class_daily_operation_claims for each row execute function public.attendance_reopen_smoke_failure();""")
    rejected('transaction rolls back on daily claim failure', 409, payload)
    sql('drop trigger attendance_reopen_smoke_failure on class_daily_operation_claims; drop function public.attendance_reopen_smoke_failure();')

    status, body = request(path, payload, principal)
    assert status == 200 and body['data']['id'] == SESSION, f'Valid correction failed ({status})'
    after = snapshot()
    target = next(row for row in after['sessions'] if row['id'] == SESSION)
    other = next(row for row in after['sessions'] if row['id'] == OTHER_SESSION)
    assert target['status'] == 'reopened' and not target['is_finalized']
    assert len(target['reopen_history']) == 1
    assert after['claims'][0]['status'] == 'reopened'
    assert after['claims'][0]['section_id'] == SECTION
    assert after['claims'][0]['reopened_by'] == target['reopened_by']
    assert other == next(row for row in before['sessions'] if row['id'] == OTHER_SESSION)
    assert after['marks'] == before['marks']
    print('PASS: correct historical register reopened after student transfer; marks and other register unchanged')
    status, _ = request(path, {**payload, 'reason': 'Retry must preserve original'}, principal)
    assert status == 200
    repeated = next(row for row in snapshot()['sessions'] if row['id'] == SESSION)
    assert repeated == target, 'Retry changed original correction history'
    print('PASS: reopen retry preserves original actor, reason, timestamp and history')
    grants = sql("""select has_function_privilege('anon', 'public.reopen_attendance_session_scoped(uuid,uuid,uuid,text,uuid,date,uuid)', 'execute'),
      has_function_privilege('authenticated', 'public.reopen_attendance_session_scoped(uuid,uuid,uuid,text,uuid,date,uuid)', 'execute'),
      has_function_privilege('service_role', 'public.reopen_attendance_session_scoped(uuid,uuid,uuid,text,uuid,date,uuid)', 'execute');""")
    assert grants == 'f|f|t', f'Unexpected RPC grants: {grants}'
    print('PASS: direct anon/authenticated RPC access denied; service_role only')

    # Reproduce the immediate support workflow: once the correct class register
    # is reopened, the unchanged teacher marking endpoint can submit corrections.
    sql(f"update students set current_section_id='{SECTION}' where id='{STUDENT}';")
    status, _ = request(f'/attendance/sessions/{SESSION}/mark', {
        'attendances': [{'student_id': STUDENT, 'status': 'present'}],
        'finalize': True,
    }, teacher)
    assert status == 200, f'Existing teacher correction submission failed ({status})'
    submitted = snapshot()
    corrected = next(row for row in submitted['sessions'] if row['id'] == SESSION)
    assert corrected['is_finalized'] and corrected['status'] == 'submitted'
    assert submitted['marks'][0]['status'] == 'present'
    assert next(row for row in submitted['sessions'] if row['id'] == OTHER_SESSION) == other
    print('PASS: unchanged teacher marking endpoint submits the reopened class correction')
finally:
    cleanup()

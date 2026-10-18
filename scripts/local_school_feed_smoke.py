#!/usr/bin/env python3
"""Scoped feed pagination, placement, attention counts and branding: Docker-local only."""
import base64
import json
import random
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = json.loads((ROOT / 'env.local.json').read_text())
API = CONFIG['API_BASE_URL'].rstrip('/')
assert urllib.parse.urlparse(API).hostname in ('localhost', '127.0.0.1', '::1'), 'Local synthetic backend only'
DB = 'supabase_db_schooldesk-local'
SCHOOL = '00000000-0000-4000-8000-000000000001'
PREFIX = 'feed-ui-' + uuid.uuid4().hex[:8]
BRANCH = str(uuid.uuid4())
IP = f'198.18.{random.randrange(1, 254)}.{random.randrange(1, 254)}'
TOKENS = {}
POSTS = [str(uuid.uuid4()) for _ in range(129)]
ACCOUNT, MIRROR = str(uuid.uuid4()), str(uuid.uuid4())
UPLOADED = None
LOGO = None


def sql(statement):
    result = subprocess.run(['docker', '--context', 'default', 'exec', '-i', DB, 'psql', '-X', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-Atq'], input=statement, text=True, capture_output=True)
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()


def request(role, path, body=None, method=None, expected=200, branch=None, content_type='application/json'):
    headers = {'Content-Type': content_type, 'x-forwarded-for': IP}
    if role:
        headers['Authorization'] = 'Bearer ' + TOKENS[role]
    if branch:
        headers['x-schooldesk-branch-id'] = branch
    payload = body if isinstance(body, bytes) else None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(API + path, data=payload, headers=headers, method=method or ('GET' if body is None else 'POST'))
    try:
        response = urllib.request.urlopen(req, timeout=60)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        data = json.load(response)
        assert response.status == expected, (path, response.status, data.get('error'))
        return data


def multipart(name, png, **fields):
    boundary = 'qa-' + uuid.uuid4().hex
    data = b''
    for key, value in fields.items():
        data += f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
    data += f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{PREFIX}.png"\r\nContent-Type: image/png\r\n\r\n'.encode() + png + f'\r\n--{boundary}--\r\n'.encode()
    return data, 'multipart/form-data; boundary=' + boundary


def page(role='PRINCIPAL', destination='FEED', number=1, branch=None):
    return request(role, f'/event-posts?published_only=true&destination={destination}&page={number}&page_size=20', branch=branch)['data']


for role in ['PRINCIPAL', 'COORDINATOR', 'TEACHER', 'PARENT', 'SECOND_SCHOOL_PRINCIPAL']:
    login = request(None, '/auth/login', {'username': CONFIG[f'QA_{role}_USERNAME'], 'password': CONFIG[f'QA_{role}_PASSWORD']})['data']
    TOKENS[role] = login.get('access_token') or login['token']
PRINCIPAL = sql(f"select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_PRINCIPAL_USERNAME']}';")
TEACHER = sql(f"select id from users where school_id='{SCHOOL}' and username='{CONFIG['QA_TEACHER_USERNAME']}';")
original_logo = sql(f"select coalesce(logo_url,'') from schools where id='{SCHOOL}';")
try:
    png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==')
    body, ctype = multipart('file', png, folder=PREFIX, entity_type='event_post', private='true')
    UPLOADED = request('PRINCIPAL', '/uploads', body, content_type=ctype)['data']
    media = json.dumps([{'url': UPLOADED['path'], 'storage_ref': UPLOADED['path'], 'kind': 'image', 'mime_type': 'image/png'}])
    base_attention = request('PRINCIPAL', '/approvals/feed?status=pending&page_size=1')['counts_by_type']
    base_dashboard = request('PRINCIPAL', '/dashboard/principal')['data']['metrics']
    statements = []
    for index, post in enumerate(POSTS[:128]):
        status = 'approved' if index < 125 else 'pending'
        statements.append(f"insert into event_posts(id,school_id,title,body,media_urls,status,created_by,destinations,approved_by,approved_at) values('{post}','{SCHOOL}','{PREFIX}-{index}','Local feed check','{media}'::jsonb,'{status}','{TEACHER}','[\"PARENTS_HOME\",\"SCHOOL_GALLERY\",\"TEACHERS_HOME\"]'::jsonb,'{PRINCIPAL}',now());")
    statements += [
        f"insert into schools(id,name,organization_id) select '{BRANCH}','{PREFIX}-branch',organization_id from schools where id='{SCHOOL}';",
        f"insert into event_posts(id,school_id,title,status,created_by,destinations) values('{POSTS[128]}','{BRANCH}','{PREFIX}-branch-post','approved','{PRINCIPAL}','[\"PARENTS_HOME\"]'::jsonb);",
        f"insert into account_approvals(id,school_id,user_id,role,status) values('{ACCOUNT}','{SCHOOL}','{TEACHER}','teacher','pending');",
        f"insert into approval_requests(id,school_id,module,entity_type,entity_id,operation_type,status,requested_by) values('{MIRROR}','{SCHOOL}','communication','event_post','{POSTS[125]}','create','pending','{TEACHER}');",
    ]
    sql('\n'.join(statements))
    logo_body, logo_type = multipart('logo', png)
    LOGO = request('PRINCIPAL', '/schools/current/logo', logo_body, branch=BRANCH, content_type=logo_type)['data']['logo_url']
    assert request('PRINCIPAL', '/schools/current', branch=BRANCH)['data']['logo_url'] == LOGO
    # Internal runtime URLs are normalized to this local public origin by Flutter.
    logo_read_url = API.split('/functions/')[0] + urllib.parse.urlparse(LOGO).path
    with urllib.request.urlopen(logo_read_url, timeout=30) as image:
        assert image.status == 200 and image.read() == png
    assert (request('PRINCIPAL', '/schools/current')['data'].get('logo_url') or '') == original_logo
    request('PARENT', '/schools/current/logo', logo_body, expected=403, content_type=logo_type)
    visible = []
    for number in range(1, 20):
        result = page(number=number)
        visible.extend(row['id'] for row in result['data'])
        if number * 20 >= result['total']:
            break
    assert len(visible) == len(set(visible))
    assert set(POSTS[:125]).issubset(visible), 'Pagination must include more than 100 posts'
    assert POSTS[125] not in visible and POSTS[128] not in visible
    assert any(row['id'] == POSTS[128] for row in page(branch=BRANCH)['data'])
    assert all(row['id'] not in POSTS for row in page(role='SECOND_SCHOOL_PRINCIPAL')['data'])
    request('TEACHER', '/event-posts?published_only=true', expected=403)
    request('PARENT', '/approvals/feed?status=pending', expected=403)
    request('TEACHER', '/approvals/feed?status=pending', expected=403)
    request('SECOND_SCHOOL_PRINCIPAL', f'/event-posts/{POSTS[0]}', {'destinations': []}, method='PUT', expected=404)
    for role in ['PARENT', 'TEACHER']:
        request(role, f'/event-posts/{POSTS[0]}', {'destinations': []}, method='PUT', expected=403)
    request('PRINCIPAL', f'/event-posts/{POSTS[0]}', {'destinations': ['UNKNOWN']}, method='PUT', expected=400)
    before = request('PRINCIPAL', f'/event-posts/{POSTS[0]}')['data']
    changed = request('COORDINATOR', f'/event-posts/{POSTS[0]}', {'destinations': ['PARENTS_HOME', 'TEACHERS_HOME']}, method='PUT')['data']
    assert changed['destinations'] == ['PARENTS_HOME', 'TEACHERS_HOME']
    for field in ['status', 'approved_by', 'approved_at', 'public_gallery_visible', 'event_date', 'title', 'body', 'visibility', 'created_by']:
        assert changed[field] == before[field], field
    assert sql(f"select destinations ? 'SCHOOL_GALLERY' from event_posts where id='{POSTS[0]}';") == 'f'
    request('PRINCIPAL', f'/event-posts/{POSTS[0]}', {'destinations': [], 'public_gallery_visible': 'false'}, method='PUT', expected=400)
    hidden = request('PRINCIPAL', f'/event-posts/{POSTS[0]}', {'destinations': [], 'public_gallery_visible': False}, method='PUT')['data']
    assert hidden['destinations'] == [] and hidden['status'] == 'approved'
    assert request('PRINCIPAL', f'/event-posts/{POSTS[0]}')['data']['destinations'] == []
    assert POSTS[0] not in [row['id'] for row in page()['data']]
    assert sql(f"select count(*) from event_posts where id='{POSTS[0]}';") == '1'
    restored = request('PRINCIPAL', f'/event-posts/{POSTS[0]}', {'destinations': ['SCHOOL_GALLERY']}, method='PUT')['data']
    assert restored['destinations'] == ['SCHOOL_GALLERY'] and restored['status'] == 'approved'
    assert any(row['id'] == POSTS[0] for number in range(1, 8) for row in page(destination='SCHOOL_GALLERY', number=number)['data'])
    attention = request('PRINCIPAL', '/approvals/feed?status=pending&page_size=1')['counts_by_type']
    assert attention.get('event', 0) == base_attention.get('event', 0) + 3, 'Generic mirror must not count twice'
    assert attention.get('account', 0) == base_attention.get('account', 0) + 1
    dashboard = request('PRINCIPAL', '/dashboard/principal')['data']['metrics']
    assert dashboard['pending_event_approvals'] == base_dashboard['pending_event_approvals'] + 3
    assert dashboard['pending_access_approvals'] == base_dashboard['pending_access_approvals'] + 1
    coordinator = request('COORDINATOR', '/approvals/feed?status=pending')['counts_by_type']
    assert not any('fee' in key or 'payment' in key for key in coordinator)
    print('PASS: 125-post pagination; branch/tenant/role boundaries; destination removal/restoration; approval preservation; deduplicated counts; coordinator finance boundary; branch logo persistence and parent upload denial.')
finally:
    sql(f"delete from approval_requests where id='{MIRROR}'; delete from account_approvals where id='{ACCOUNT}'; delete from event_posts where title like '{PREFIX}%'; delete from schools where id='{BRANCH}';")
    storage_refs = [UPLOADED['path']] if UPLOADED else []
    if LOGO:
        storage_refs.append(urllib.parse.unquote(urllib.parse.urlparse(LOGO).path.split('/storage/v1/object/public/', 1)[1]))
    if storage_refs:
        env = {}
        for line in (ROOT / 'supabase/.env.local').read_text().splitlines():
            if '=' in line and not line.startswith('#'):
                name, value = line.split('=', 1); env[name] = value.strip().strip('"')
        service = env['SUPABASE_SERVICE_ROLE_KEY']
        origin = API.split('/functions/')[0]
        for ref in storage_refs:
            bucket, key = ref.split('/', 1)
            deletion = urllib.request.Request(origin + '/storage/v1/object/' + bucket, data=json.dumps({'prefixes': [key]}).encode(), headers={'Authorization': 'Bearer ' + service, 'apikey': service, 'Content-Type': 'application/json'}, method='DELETE')
            with urllib.request.urlopen(deletion, timeout=30) as response:
                assert response.status == 200
        if UPLOADED:
            file_id = UPLOADED['file']['id']
            sql(f"delete from uploaded_files where id='{file_id}';")
    assert sql(f"select coalesce(logo_url,'') from schools where id='{SCHOOL}';") == original_logo

#!/usr/bin/env python3
"""Host-side scheduled delivery for the self-hosted stack; secrets stay in memory."""
import argparse
import json
import subprocess
import urllib.request

JOBS = {
    'processor': ('notification-processor', {}),
    'birthday-morning': ('api/jobs/birthday-alerts/run', {'delivery_window':'morning'}),
    'birthday-afternoon': ('api/jobs/birthday-alerts/run', {'delivery_window':'afternoon'}),
    'health': ('api/jobs/health-reminders/run', {}),
}
parser = argparse.ArgumentParser()
parser.add_argument('job', choices=JOBS)
parser.add_argument('--dry-run', action='store_true')
args = parser.parse_args()
route, body = JOBS[args.job]
if args.dry_run:
    print(json.dumps({'job':args.job,'route':route,'body':body}))
    raise SystemExit(0)
names = subprocess.check_output(['docker','ps','--format','{{.Names}}'],text=True).splitlines()
containers = [name for name in names if name.startswith(('supabase-edge-functions-','supabase-functions-'))]
if len(containers) != 1:
    raise SystemExit('Expected exactly one active SchoolDesk Functions container')
container = json.loads(subprocess.check_output(['docker','inspect',containers[0]],text=True))[0]
env = dict(value.split('=',1) for value in container['Config']['Env'] if '=' in value)
key = (env.get('NOTIFICATION_PROCESSOR_SECRET') if args.job=='processor' else '') or env.get('SUPABASE_SERVICE_ROLE_KEY')
if not key:
    raise SystemExit('The job authorization key is unavailable')
kong_name = next((name for name in names if name.startswith('supabase-kong-')), None)
if not kong_name:
    raise SystemExit('The private Supabase gateway is unavailable')
kong = json.loads(subprocess.check_output(['docker','inspect',kong_name],text=True))[0]
kong_env = dict(value.split('=',1) for value in kong['Config']['Env'] if '=' in value)
gateway_ip = next((network['IPAddress'] for network in kong['NetworkSettings']['Networks'].values() if network.get('IPAddress')), None)
if not gateway_ip:
    raise SystemExit('The private gateway address is unavailable')
# Use the existing private Docker gateway: scheduled host jobs must not depend
# on the public reverse proxy's bot protection or external DNS.
req = urllib.request.Request('http://'+gateway_ip+':8000/functions/v1/'+route,data=json.dumps(body).encode(),headers={
    'Content-Type':'application/json','Authorization':'Bearer '+key,
    'apikey':kong_env.get('SUPABASE_ANON_KEY') or env.get('SUPABASE_ANON_KEY') or key,
})
try:
    with urllib.request.urlopen(req,timeout=110) as response:
        result = json.loads(response.read())
        if result.get('success') is False:
            raise RuntimeError('The scheduled API job reported failure')
        # Counts and outcomes only; never log payloads containing child details.
        print(json.dumps({'job':args.job,'status':response.status,'completed':True}))
except Exception as error:
    raise SystemExit(f'{args.job} failed ({type(error).__name__}, HTTP {getattr(error, 'code', 'n/a')}); inspect the service/API logs') from None

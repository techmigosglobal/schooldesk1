#!/usr/bin/env bash
set -Eeuo pipefail
# Run on the production host only, after deploying/verifying the API and worker.
[[ "$(id -u)" == 0 ]] || { echo 'Run as root on the deployment host' >&2; exit 1; }
[[ -d /data/schooldesk/functions/api ]] || { echo 'SchoolDesk production Functions mount not found' >&2; exit 1; }
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -d -m 0750 /usr/local/lib/schooldesk
install -m 0750 "$script_dir/notification_jobs.py" /usr/local/lib/schooldesk/notification_jobs.py
cat > /etc/systemd/system/schooldesk-notification@.service <<'UNIT'
[Unit]
Description=SchoolDesk notification job (%i)
After=docker.service network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/local/lib/schooldesk/notification_jobs.py %i
TimeoutStartSec=120
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
UNIT
for job in processor birthday-morning birthday-afternoon health; do
  case "$job" in
    processor) schedule='';;
    birthday-morning) schedule='*-*-* 09:00:00 Asia/Kolkata';;
    birthday-afternoon) schedule='*-*-* 15:00:00 Asia/Kolkata';;
    health) schedule='*-*-* 16:00:00 Asia/Kolkata';;
  esac
  {
    echo '[Unit]'
    echo "Description=SchoolDesk $job schedule"
    echo '[Timer]'
    if [[ "$job" == processor ]]; then
      echo 'OnBootSec=90s'
      echo 'OnUnitActiveSec=2min'
    else
      echo "OnCalendar=$schedule"
      echo 'Persistent=true'
    fi
    echo "Unit=schooldesk-notification@$job.service"
    echo '[Install]'
    echo 'WantedBy=timers.target'
  } > "/etc/systemd/system/schooldesk-notification-$job.timer"
done
# Initialize new persistent timers at installation time so enabling scheduling
# does not broadcast both missed birthday windows immediately on rollout.
install -d -m 0755 /var/lib/systemd/timers
for job in birthday-morning birthday-afternoon health; do
  timer_stamp="/var/lib/systemd/timers/stamp-schooldesk-notification-$job.timer"
  [[ -e "$timer_stamp" ]] || touch "$timer_stamp"
done
systemctl daemon-reload
systemctl enable --now schooldesk-notification-processor.timer schooldesk-notification-birthday-morning.timer schooldesk-notification-birthday-afternoon.timer schooldesk-notification-health.timer
systemctl list-timers --all --no-pager 'schooldesk-notification-*'

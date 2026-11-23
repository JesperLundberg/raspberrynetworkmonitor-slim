#!/bin/sh
set -e

# If a backup exists on disk, restore it into tmpfs
if [ -f /opt/netmon/backups/netmon.db ]; then
  cp /opt/netmon/backups/netmon.db /opt/netmon/db/netmon.db
fi

# busybox crond passes its own environment (TZ, LUA_PATH from the image ENV)
# on to every job.
crond -f -l 8 -c /etc/crontabs &
CRON_PID=$!

# Plots and status.json are rewritten under fixed URLs; the page cache-busts them.
httpd -f -p 8080 -h /var/www/html &
HTTPD_PID=$!

# Take a final backup on shutdown so a `docker stop` loses no data.
shutdown() {
  kill "$CRON_PID" "$HTTPD_PID" 2>/dev/null || true
  /opt/netmon/backup.sh || true
  exit 0
}
trap shutdown TERM INT

# `wait` returns when a trapped signal arrives; neither daemon exits normally.
wait

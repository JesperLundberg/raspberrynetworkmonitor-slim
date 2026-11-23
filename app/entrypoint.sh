#!/bin/sh
set -e

# Ensure DB directory exists on tmpfs
mkdir -p /opt/netmon/db

# If a backup exists on disk, restore it into tmpfs
if [ -f /opt/netmon/backups/netmon.db ]; then
  cp /opt/netmon/backups/netmon.db /opt/netmon/db/netmon.db
fi

# busybox crond passes its own environment (TZ, LUA_PATH from the image ENV)
# on to every job.

# Take a final backup on shutdown so a `docker stop` loses no data.
crond -f -l 8 -c /etc/crontabs &
CRON_PID=$!

shutdown() {
  kill "$CRON_PID" 2>/dev/null || true
  /opt/netmon/backup.sh || true
  exit 0
}
trap shutdown TERM INT

# `wait` returns when a trapped signal arrives; cron itself never exits normally.
wait "$CRON_PID"

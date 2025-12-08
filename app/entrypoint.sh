#!/bin/sh
set -e

# Ensure DB directory exists on tmpfs
mkdir -p /opt/netmon/db

# If a backup exists on disk, restore it into tmpfs
if [ -f /opt/netmon/backups/netmon.db ]; then
  cp /opt/netmon/backups/netmon.db /opt/netmon/db/netmon.db
fi

export LUA_PATH="/opt/netmon/lua/?.lua;/opt/netmon/lua/?/init.lua;;"

# Start cron in the foreground
exec cron -f

#!/bin/sh
set -eu

# Copy the tmpfs database to disk. Write to a temp file first so a crash
# mid-backup cannot corrupt the previous good backup.
DB="/opt/netmon/db/netmon.db"
DEST="/opt/netmon/backups/netmon.db"

[ -f "$DB" ] || exit 0

sqlite3 "$DB" ".backup '$DEST.tmp'"
mv "$DEST.tmp" "$DEST"

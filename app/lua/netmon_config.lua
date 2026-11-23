local C = {}

C.DB_DIR = "/opt/netmon/db"
C.DB_PATH = C.DB_DIR .. "/netmon.db"
C.ARCHIVE_DIR = "/opt/netmon/archive"
C.JSON_DIR = "/var/www/html/netmon"
C.JSON_PATH = C.JSON_DIR .. "/status.json"

-- Hosts pinged by net_ping.lua and shown by update_status.lua.
-- make_plots.sh has the same two hosts in its ping filters; change both together.
C.PING_HOSTS = { "1.1.1.1", "8.8.8.8" }

-- Rows older than this are exported to a CSV in ARCHIVE_DIR and then deleted.
-- The DB lives on a small tmpfs, so this bounds its size.
C.RETENTION_DAYS = 30

return C

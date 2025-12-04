#!/usr/bin/env luajit

-- Ping 1.1.1.1 and 8.8.8.8 and store avg RTT + packet loss in SQLite.
-- Appends rows to table "ping": ts INTEGER, host TEXT, rtt_ms REAL, packet_loss REAL.

local sqlite3 = require "lsqlite3"

local DB_PATH = "/opt/netmon/netmon.db"

-- ---------- shell helper ----------

local function run_cmd(cmd)
  local f = io.popen(cmd, "r")
  if not f then return "" end
  local out = f:read("*a") or ""
  f:close()
  return out
end

-- Parse ping output for avg RTT (ms) and packet loss (%)
local function parse_ping_output(output)
  if not output or output == "" then
    return 0.0, 100.0
  end

  -- packet loss
  local loss = output:match("(%d+)%%[%s%-]+packet loss")
              or output:match("(%d+)%%[%s%-]+loss")
  loss = tonumber(loss) or 0.0

  -- avg RTT: handle both "rtt" and "round-trip" variants
  local avg = output:match("rtt [^=]+= %d+%.?%d*/([%d%.]+)/")
          or  output:match("round%-trip [^=]+= %d+%.?%d*/([%d%.]+)/")
  avg = tonumber(avg) or 0.0

  return avg, loss
end

local function ping_host(host)
  -- -c 4 = four packets, -n = numeric only
  local cmd = string.format("ping -n -c 4 %s 2>/dev/null", host)
  local out = run_cmd(cmd)
  local rtt, loss = parse_ping_output(out)
  return rtt, loss
end

-- ---------- SQLite helpers ----------

local function open_db()
  local db = sqlite3.open(DB_PATH)
  assert(db, "Failed to open database: " .. DB_PATH)

  db:exec([[
    CREATE TABLE IF NOT EXISTS ping (
      ts          INTEGER NOT NULL,
      host        TEXT    NOT NULL,
      rtt_ms      REAL,
      packet_loss REAL
    );
  ]])

  db:exec("PRAGMA busy_timeout = 2000;")
  return db
end

local function insert_ping(db, ts, host, rtt_ms, packet_loss)
  local stmt = db:prepare(
    "INSERT INTO ping (ts, host, rtt_ms, packet_loss) VALUES (?, ?, ?, ?);"
  )
  assert(stmt, "Failed to prepare INSERT into ping")
  stmt:bind_values(ts, host, rtt_ms, packet_loss)
  assert(stmt:step() == sqlite3.DONE, "INSERT into ping failed")
  stmt:finalize()
end

-- ---------- main ----------

local ts = os.time()
local db = open_db()

local hosts = { "1.1.1.1", "8.8.8.8" }

for _, host in ipairs(hosts) do
  local rtt, loss = ping_host(host)
  insert_ping(db, ts, host, rtt, loss)
  io.stdout:write(string.format(
    "ping %s: rtt=%.2f ms loss=%.1f%%\n",
    host, rtt, loss
  ))
end

db:close()

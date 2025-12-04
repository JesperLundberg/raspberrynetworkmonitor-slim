#!/usr/bin/env luajit

-- Generate /var/www/html/netmon/status.json with latest values
-- Requires lsqlite3 and the existing netmon.db schema.

local sqlite3 = require "lsqlite3"

local DB_PATH   = "/opt/netmon/netmon.db"
local JSON_PATH = "/var/www/html/netmon/status.json"

-- Open SQLite and set busy timeout
local function open_db()
  local db = sqlite3.open(DB_PATH)
  assert(db, "Failed to open database: " .. DB_PATH)
  db:exec("PRAGMA busy_timeout = 2000;")
  return db
end

-- Fetch a single row as a table (or nil)
local function fetch_one(db, sql)
  local row
  for r in db:nrows(sql) do
    row = r
    break
  end
  return row
end

-- Very small JSON helpers

local function json_number(v)
  if v == nil then
    return "null"
  end
  return tostring(v)
end

local function json_status(now, ping_1111, ping_8888, speed, devices)
  local parts = {}
  local function add(s) table.insert(parts, s) end

  add("{\n")
  add(string.format('  "generated_at": %d,\n', now))

  -- Ping block
  add('  "ping": {\n')
  if ping_1111 then
    add(string.format(
      '    "host_1_1_1_1": {"ts": %d, "rtt_ms": %s, "packet_loss": %s},\n',
      ping_1111.ts or 0,
      json_number(ping_1111.rtt_ms),
      json_number(ping_1111.packet_loss)
    ))
  else
    add('    "host_1_1_1_1": null,\n')
  end

  if ping_8888 then
    add(string.format(
      '    "host_8_8_8_8": {"ts": %d, "rtt_ms": %s, "packet_loss": %s}\n',
      ping_8888.ts or 0,
      json_number(ping_8888.rtt_ms),
      json_number(ping_8888.packet_loss)
    ))
  else
    add('    "host_8_8_8_8": null\n')
  end
  add("  },\n")

  -- Speed block
  add('  "speed": ')
  if speed then
    add(string.format(
      '{"ts": %d, "download_mbps": %s, "upload_mbps": %s},\n',
      speed.ts or 0,
      json_number(speed.download_mbps),
      json_number(speed.upload_mbps)
    ))
  else
    add("null,\n")
  end

  -- Devices block
  add('  "devices": ')
  if devices then
    add(string.format(
      '{"ts": %d, "device_count": %s}\n',
      devices.ts or 0,
      json_number(devices.device_count)
    ))
  else
    add("null\n")
  end

  add("}\n")
  return table.concat(parts)
end

-- Main logic

local now = os.time()
local db = open_db()

local ping_1111 = fetch_one(db, [[
  SELECT ts, rtt_ms, packet_loss
  FROM ping
  WHERE host = '1.1.1.1'
  ORDER BY ts DESC
  LIMIT 1;
]])

local ping_8888 = fetch_one(db, [[
  SELECT ts, rtt_ms, packet_loss
  FROM ping
  WHERE host = '8.8.8.8'
  ORDER BY ts DESC
  LIMIT 1;
]])

local speed = fetch_one(db, [[
  SELECT ts, download_mbps, upload_mbps
  FROM speed
  ORDER BY ts DESC
  LIMIT 1;
]])

local devices = fetch_one(db, [[
  SELECT ts, device_count
  FROM devices
  ORDER BY ts DESC
  LIMIT 1;
]])

db:close()

local json = json_status(now, ping_1111, ping_8888, speed, devices)

local f, err = io.open(JSON_PATH, "w")
assert(f, "Failed to open status.json for write: " .. tostring(err))
f:write(json)
f:close()

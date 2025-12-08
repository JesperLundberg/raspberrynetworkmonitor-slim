#!/usr/bin/env luajit

local sqlite3 = require("lsqlite3")
local utils = require("netmon_utils")
local config = require("netmon_config")

local DB_PATH = config.DB_PATH

local function iface_exists(iface)
	local f = io.open("/sys/class/net/" .. iface, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function detect_iface()
	-- Allow both NETMON_IFACE and ARP_SCAN_IFACE as overrides
	local env = os.getenv("NETMON_IFACE") or os.getenv("ARP_SCAN_IFACE")
	if env and env ~= "" and iface_exists(env) then
		return env
	end
	if iface_exists("eth0") then
		return "eth0"
	end
	if iface_exists("wlan0") then
		return "wlan0"
	end
	return nil
end

local INTERFACE = detect_iface()
if not INTERFACE then
	io.stderr:write("net_devices.lua: no suitable interface found\n")
	os.exit(1)
end

local function open_db()
	local db = utils.open_db(DB_PATH)

	-- Ensure table exists
	local ok, exec_err = db:exec([[
    CREATE TABLE IF NOT EXISTS devices (
      ts           INTEGER NOT NULL,
      device_count INTEGER
    );
  ]])

	assert(ok == sqlite3.OK, "Failed to create devices table: " .. tostring(exec_err))

	return db
end

local function insert_devices(db, ts, count)
	local stmt = db:prepare("INSERT INTO devices (ts, device_count) VALUES (?, ?);")
	assert(stmt, "Failed to prepare INSERT into devices")
	stmt:bind_values(ts, count)
	assert(stmt:step() == sqlite3.DONE, "INSERT into devices failed")
	stmt:finalize()
end

local function scan_devices(iface)
	-- Example arp-scan output lines:
	-- 192.168.1.1   7c:77:16:12:8a:a8   Some Vendor
	-- We only care about the IP and deduplicate.
	local cmd = string.format("/usr/sbin/arp-scan --localnet --interface=%s 2>/dev/null", iface)
	local out = utils.run_cmd(cmd)

	local seen = {}

	for line in out:gmatch("[^\r\n]+") do
		local ip = line:match("^(%d+%.%d+%.%d+%.%d+)%s+[%x:]+%s+")
		if ip then
			seen[ip] = true
		end
	end

	return seen
end

local neighbors = scan_devices(INTERFACE)

local count = 0
for _ in pairs(neighbors) do
	count = count + 1
end

local ts = os.time()
local db = open_db()
insert_devices(db, ts, count)
db:close()

io.stdout:write(string.format("net_devices.lua: iface=%s count=%d\n", INTERFACE, count))

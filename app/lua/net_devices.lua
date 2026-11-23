#!/usr/bin/env luajit

local sqlite3 = require("lsqlite3")
local utils = require("netmon_utils")
local config = require("netmon_config")
local parse = require("netmon_parse")

local function iface_exists(iface)
	local f = io.open("/sys/class/net/" .. iface, "r")
	if f then
		f:close()
		return true
	end
	return false
end

-- Interface carrying the default route. The container uses host networking, so
-- this is the host's routing table and works for any naming scheme (eth0, enu1u1, ...).
local function default_route_iface()
	local f = io.open("/proc/net/route", "r")
	if not f then
		return nil
	end
	for line in f:lines() do
		local iface, dest = line:match("^(%S+)%s+(%x+)")
		if dest == "00000000" then
			f:close()
			return iface
		end
	end
	f:close()
	return nil
end

local function detect_iface()
	-- Allow both NETMON_IFACE and ARP_SCAN_IFACE as overrides
	local env = os.getenv("NETMON_IFACE") or os.getenv("ARP_SCAN_IFACE")
	if env and env ~= "" and iface_exists(env) then
		return env
	end
	local route = default_route_iface()
	if route and iface_exists(route) then
		return route
	end
	if iface_exists("eth0") then
		return "eth0"
	end
	if iface_exists("wlan0") then
		return "wlan0"
	end
	return nil
end

local function open_db()
	utils.ensure_dir(config.DB_DIR)
	local db = utils.open_db(config.DB_PATH)
	local rc = db:exec([[
    CREATE TABLE IF NOT EXISTS devices (
      ts           INTEGER NOT NULL,
      device_count INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_devices_ts ON devices(ts);
  ]])
	assert(rc == sqlite3.OK, "Failed to create devices table: " .. db:errmsg())
	return db
end

local function insert_devices(db, ts, count)
	local stmt = assert(db:prepare("INSERT INTO devices (ts, device_count) VALUES (?, ?);"), db:errmsg())
	assert(stmt:bind_values(ts, count) == sqlite3.OK, "bind failed: " .. db:errmsg())
	local rc = stmt:step()
	stmt:finalize()
	assert(rc == sqlite3.DONE, "INSERT into devices failed: " .. db:errmsg())
end

local function main()
	local iface = detect_iface()
	if not iface then
		io.stderr:write("net_devices.lua: no suitable interface found\n")
		os.exit(1)
	end

	-- arp-scan is on PATH in the Alpine image; no hardcoded sbin location.
	-- stderr is kept so scan errors end up in the output we log on failure.
	local out = utils.run_cmd(string.format("arp-scan --localnet --interface=%s 2>&1", iface))
	local count = parse.count_arp_scan(out)

	-- No replies at all almost always means the scan failed (missing capability,
	-- interface down), not that the LAN is empty. Record a gap instead of 0.
	if count == 0 then
		io.stderr:write(string.format("net_devices.lua: iface=%s: arp-scan found no devices; skipping sample\n%s\n", iface, out))
		os.exit(1)
	end

	local db = open_db()
	insert_devices(db, os.time(), count)
	db:close()

	io.stdout:write(string.format("net_devices.lua: iface=%s count=%d\n", iface, count))
end

main()

#!/usr/bin/env luajit

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
	local env = os.getenv("NETMON_IFACE")
	if env and env ~= "" and iface_exists(env) then
		return env
	end
	local route = default_route_iface()
	if route and iface_exists(route) then
		return route
	end
	return nil
end

local SCHEMA = [[
    CREATE TABLE IF NOT EXISTS devices (
      ts           INTEGER NOT NULL,
      device_count INTEGER
    );
    CREATE INDEX IF NOT EXISTS idx_devices_ts ON devices(ts);
  ]]

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

	local db = utils.open_db(config.DB_PATH, SCHEMA)
	utils.insert(db, "INSERT INTO devices (ts, device_count) VALUES (?, ?);", os.time(), count)
	db:close()

	io.stdout:write(string.format("net_devices.lua: iface=%s count=%d\n", iface, count))
end

main()

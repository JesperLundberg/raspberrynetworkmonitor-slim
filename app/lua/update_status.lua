#!/usr/bin/env luajit

local json = require("dkjson")
local utils = require("netmon_utils")
local config = require("netmon_config")

local PING_HOSTS = {
	"1.1.1.1",
	"8.8.8.8",
}

--Fetch the latest ping row for each host in PING_HOSTS.
local function get_latest_ping_for_hosts(db, hosts)
	local result = {}

	for _, host in ipairs(hosts) do
		local sql = string.format(
			[[
      SELECT ts, host, rtt_ms, packet_loss
      FROM ping
      WHERE host = '%s'
      ORDER BY ts DESC
      LIMIT 1;
    ]],
			host
		)

		local row = utils.fetch_one(db, sql)
		result[host] = row
	end

	return result
end

--Fetch the latest speed row, if any.
local function get_latest_speed(db)
	local sql = [[
    SELECT ts, download_mbps, upload_mbps
    FROM speed
    ORDER BY ts DESC
    LIMIT 1;
  ]]
	return utils.fetch_one(db, sql)
end

--Fetch the latest devices row, if any.
local function get_latest_devices(db)
	local sql = [[
    SELECT ts, device_count
    FROM devices
    ORDER BY ts DESC
    LIMIT 1;
  ]]
	return utils.fetch_one(db, sql)
end

--Build the status JSON document as a string.
local function json_status(now_ts, ping_rows, speed_row, devices_row)
	-- Build ping section as a map from host -> object or null
	local ping_obj = {}
	for host, row in pairs(ping_rows) do
		if row then
			ping_obj[host] = {
				ts = row.ts or 0,
				rtt_ms = row.rtt_ms,
				packet_loss = row.packet_loss,
			}
		else
			ping_obj[host] = json.null
		end
	end

	-- Optional speed section
	local speed_obj
	if speed_row then
		speed_obj = {
			ts = speed_row.ts or 0,
			download_mbps = speed_row.download_mbps,
			upload_mbps = speed_row.upload_mbps,
		}
	else
		speed_obj = json.null
	end

	-- Optional devices section
	local devices_obj
	if devices_row then
		devices_obj = {
			ts = devices_row.ts or 0,
			device_count = devices_row.device_count,
		}
	else
		devices_obj = json.null
	end

	-- Complete document
	local doc = {
		generated_at = now_ts,
		ping = ping_obj,
		speed = speed_obj,
		devices = devices_obj,
	}

	-- Pretty JSON (indent=true)
	local json_str, err = json.encode(doc, { indent = true })
	assert(json_str, "Failed to encode status JSON: " .. tostring(err))

	return json_str
end

--Main entry point: read latest rows and write status.json.
local function main()
	local db = utils.open_db(config.DB_PATH)

	local ping_rows = get_latest_ping_for_hosts(db, PING_HOSTS)
	local speed_row = get_latest_speed(db)
	local devices_row = get_latest_devices(db)

	db:close()

	local now_ts = os.time()
	local body = json_status(now_ts, ping_rows, speed_row, devices_row)

	local f, err = io.open(config.JSON_PATH, "w")
	assert(f, "Failed to open status JSON file: " .. tostring(err))
	f:write(body)
	f:close()
end

main()

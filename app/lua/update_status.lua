#!/usr/bin/env luajit

local json = require("dkjson")
local utils = require("netmon_utils")
local config = require("netmon_config")

-- Latest ping row per configured host, keyed by host (false when there is none).
local function get_latest_ping_for_hosts(db, hosts)
	local result = {}
	for _, host in ipairs(hosts) do
		result[host] = utils.fetch_one(
			db,
			"SELECT ts, host, rtt_ms, packet_loss FROM ping WHERE host = ? ORDER BY ts DESC LIMIT 1;",
			host
		) or false
	end
	return result
end

local function get_latest_speed(db)
	return utils.fetch_one(db, "SELECT ts, download_mbps, upload_mbps FROM speed ORDER BY ts DESC LIMIT 1;")
end

local function get_latest_devices(db)
	return utils.fetch_one(db, "SELECT ts, device_count FROM devices ORDER BY ts DESC LIMIT 1;")
end

-- The jobs create their own tables on first run, so right after a fresh start
-- some may not exist yet. A missing table simply means "no data".
local function latest_or_null(db, table_name, getter)
	if not utils.table_exists(db, table_name) then
		return nil
	end
	return getter(db)
end

local function build_document(now_ts, ping_rows, speed_row, devices_row)
	local ping_obj = {}
	for host, row in pairs(ping_rows) do
		if row then
			ping_obj[host] = { ts = row.ts or 0, rtt_ms = row.rtt_ms, packet_loss = row.packet_loss }
		else
			ping_obj[host] = json.null
		end
	end

	return {
		generated_at = now_ts,
		ping = ping_obj,
		speed = speed_row
				and { ts = speed_row.ts or 0, download_mbps = speed_row.download_mbps, upload_mbps = speed_row.upload_mbps }
			or json.null,
		devices = devices_row and { ts = devices_row.ts or 0, device_count = devices_row.device_count } or json.null,
	}
end

local function main()
	local db = utils.open_db(config.DB_PATH)

	local ping_rows = {}
	if utils.table_exists(db, "ping") then
		ping_rows = get_latest_ping_for_hosts(db, config.PING_HOSTS)
	end
	local speed_row = latest_or_null(db, "speed", get_latest_speed)
	local devices_row = latest_or_null(db, "devices", get_latest_devices)

	db:close()

	local body = json.encode(build_document(os.time(), ping_rows, speed_row, devices_row), { indent = true })
	assert(body, "Failed to encode status JSON")

	utils.ensure_dir(config.JSON_DIR)
	utils.write_atomic(config.JSON_PATH, body)
end

main()

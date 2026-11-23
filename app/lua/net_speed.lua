#!/usr/bin/env luajit

local utils = require("netmon_utils")
local config = require("netmon_config")
local parse = require("netmon_parse")

-- First URL that delivers wins. The old speed.hetzner.de endpoint no longer resolves.
local DOWNLOAD_URLS = {
	"https://speed.cloudflare.com/__down?bytes=10000000",
	"http://ipv4.download.thinkbroadband.com/10MB.zip",
}

local UPLOAD_URL = "https://speed.cloudflare.com/__up"
local UPLOAD_SIZE = 512 * 1024 -- bytes

local EMPTY_JSON = '{"bytes":0,"time":0}'

local SCHEMA = [[
    CREATE TABLE IF NOT EXISTS speed (
      ts            INTEGER NOT NULL,
      download_mbps REAL,
      upload_mbps   REAL
    );
    CREATE INDEX IF NOT EXISTS idx_speed_ts ON speed(ts);
  ]]

-- Returns Mbit/s, or nil when nothing was transferred.
local function calc_mbit(bytes, seconds)
	if bytes <= 0 or seconds <= 0 then
		return nil
	end
	return (bytes / seconds) * 8.0 / 1000000.0
end

local function fmt(v)
	return v and string.format("%.2f", v) or "n/a"
end

local function measure_download()
	for _, url in ipairs(DOWNLOAD_URLS) do
		-- -f makes HTTP errors count as failure instead of timing an error page.
		local cmd = string.format(
			"curl -4 -fL -o /dev/null -s --max-time 20 -w '{\"bytes\":%%{size_download},\"time\":%%{time_total}}' '%s' || echo '%s'",
			url,
			EMPTY_JSON
		)
		local bytes, secs = parse.parse_json_bytes_time(utils.run_cmd(cmd))
		local mbit = calc_mbit(bytes, secs)
		if mbit then
			return mbit
		end
	end
	return nil
end

local function measure_upload()
	-- Generate UPLOAD_SIZE bytes from /dev/zero and pipe to curl.
	local cmd = string.format(
		"dd if=/dev/zero bs=%d count=1 2>/dev/null | curl -4 -fs -o /dev/null --max-time 20 "
			.. "-w '{\"bytes\":%%{size_upload},\"time\":%%{time_total}}' -X POST --data-binary @- '%s' || echo '%s'",
		UPLOAD_SIZE,
		UPLOAD_URL,
		EMPTY_JSON
	)
	local bytes, secs = parse.parse_json_bytes_time(utils.run_cmd(cmd))
	return calc_mbit(bytes, secs)
end

local function main()
	-- A failed measurement is stored as NULL so the plot shows a gap, not a drop to 0.
	local dl_mbit = measure_download()
	local ul_mbit = measure_upload()

	local db = utils.open_db(config.DB_PATH, SCHEMA)
	local ts = os.time()
	utils.insert(db, "INSERT INTO speed (ts, download_mbps, upload_mbps) VALUES (?, ?, ?);", ts, dl_mbit, ul_mbit)
	db:close()

	io.stdout:write(string.format("Saved speed sample at %d: dl=%s Mbps, ul=%s Mbps\n", ts, fmt(dl_mbit), fmt(ul_mbit)))
end

main()

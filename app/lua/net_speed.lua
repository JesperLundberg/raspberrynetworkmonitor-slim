#!/usr/bin/env luajit

local sqlite3 = require("lsqlite3")
local utils = require("netmon_utils")
local config = require("netmon_config")

local DB_PATH = config.DB_PATH

local DOWNLOAD_URLS = {
	"https://speed.hetzner.de/10MB.bin",
	"https://speed.cloudflare.com/__down?bytes=10000000",
	"http://ipv4.download.thinkbroadband.com/10MB.zip",
}

local UPLOAD_URL = "https://speed.cloudflare.com/__up"
local UPLOAD_SIZE = 512 * 1024 -- bytes

--Open the speed table in the main database.
local function open_db()
	local db = utils.open_db(DB_PATH)
	local ok, exec_err = db:exec([[
    CREATE TABLE IF NOT EXISTS speed (
      ts            INTEGER NOT NULL,
      download_mbps REAL,
      upload_mbps   REAL
    );
  ]])
	assert(ok == sqlite3.OK, "Failed to create speed table: " .. tostring(exec_err))
	return db
end

local function insert_speed(db, ts, dl_mbps, ul_mbps)
	local stmt = db:prepare("INSERT INTO speed (ts, download_mbps, upload_mbps) VALUES (?, ?, ?);")
	assert(stmt, "Failed to prepare INSERT into speed")

	stmt:bind_values(ts, dl_mbps, ul_mbps)
	local rc = stmt:step()
	stmt:finalize()

	assert(rc == sqlite3.DONE, "INSERT into speed failed with rc=" .. tostring(rc))
end

-- Parse {"bytes":123,"time":0.123} into numbers
local function parse_json_bytes_time(s)
	local b = s:match('"bytes"%s*:%s*(%d+)')
	local t = s:match('"time"%s*:%s*([%d%.]+)')
	return tonumber(b) or 0, tonumber(t) or 0.0
end

local function calc_mbit(bytes, seconds)
	if not seconds or seconds <= 0 then
		return 0.0
	end
	return (bytes / seconds) * 8.0 / 1000000.0
end

local function fmt(v)
	return string.format("%.2f", v or 0)
end

local dl_bytes, dl_time = 0, 0.0

for _, url in ipairs(DOWNLOAD_URLS) do
	local cmd_download = string.format(
		"curl -4 -L -o /dev/null -s "
			.. "--max-time 20 "
			.. "-w '{\"bytes\":%%{size_download},\"time\":%%{time_total}}' '%s' "
			.. '|| echo \'{"bytes":0,"time":0}\'',
		url
	)
	local json = utils.run_cmd(cmd_download)
	local b, t = parse_json_bytes_time(json)
	if b > 0 then
		dl_bytes, dl_time = b, t
		break
	end
end

local dl_mbit = 0.0
if dl_bytes > 0 then
	dl_mbit = calc_mbit(dl_bytes, dl_time)
end

-- Generate UPLOAD_SIZE bytes from /dev/zero and pipe to curl
local cmd_upload = string.format(
	"dd if=/dev/zero bs=%d count=1 2>/dev/null | "
		.. "curl -4 -s -o /dev/null --max-time 20 "
		.. '-w \'{"bytes":%%{size_upload},"time":%%{time_total}}\' '
		.. "-X POST --data-binary @- '%s' "
		.. '|| echo \'{"bytes":0,"time":0}\'',
	UPLOAD_SIZE,
	UPLOAD_URL
)

local ul_json = utils.run_cmd(cmd_upload)
local ul_bytes, ul_time = parse_json_bytes_time(ul_json)

local ul_mbit = 0.0
if ul_bytes > 0 then
	ul_mbit = calc_mbit(ul_bytes, ul_time)
end

local db = open_db()
local ts = os.time()

insert_speed(db, ts, dl_mbit, ul_mbit)
db:close()

io.stdout:write(string.format("Saved speed sample at %d: dl=%s Mbps, ul=%s Mbps\n", ts, fmt(dl_mbit), fmt(ul_mbit)))

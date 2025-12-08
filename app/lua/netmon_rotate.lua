#!/usr/bin/env luajit

local sqlite3 = require("lsqlite3")
local utils = require("netmon_utils")
local config = require("netmon_config")

local LIVE_DB_PATH = config.DB_PATH
local ARCHIVE_DIR = config.ARCHIVE_DIR

-- Make sure archive directory exists
utils.ensure_dir(ARCHIVE_DIR)

-- Open live DB (shared helper sets busy_timeout etc.)
local live_db = utils.open_db(LIVE_DB_PATH)

-- We keep only rows from this year in the live DB
local CURRENT_YEAR = tonumber(os.date("%Y"))

-- Cache for archive DB handles and their prepared INSERT statements
local archive_dbs = {}
local archive_stmts = {}

-- Open (or create) an archive DB for a specific year and prepare INSERT statements
local function get_archive_db_and_stmts(year)
	-- Shortcut if handle already exists
	if archive_dbs[year] then
		return archive_dbs[year], archive_stmts[year]
	end

	local path = string.format("%s/netmon_%d.db", ARCHIVE_DIR, year)
	local adb = utils.open_db(path)

	-- Ensure tables exist in the archive DB
	local create_sql = [[
    CREATE TABLE IF NOT EXISTS ping (
      ts          INTEGER NOT NULL,
      host        TEXT    NOT NULL,
      rtt_ms      REAL,
      packet_loss REAL
    );

    CREATE TABLE IF NOT EXISTS speed (
      ts            INTEGER NOT NULL,
      download_mbps REAL,
      upload_mbps   REAL
    );

    CREATE TABLE IF NOT EXISTS devices (
      ts           INTEGER NOT NULL,
      device_count INTEGER
    );
  ]]
	assert(adb:exec(create_sql) == sqlite3.OK, "Failed to create archive tables")

	local stmts = {}

	stmts.ping = assert(
		adb:prepare("INSERT INTO ping (ts, host, rtt_ms, packet_loss) VALUES (?, ?, ?, ?);"),
		"Failed to prepare INSERT for ping in archive DB"
	)

	stmts.speed = assert(
		adb:prepare("INSERT INTO speed (ts, download_mbps, upload_mbps) VALUES (?, ?, ?);"),
		"Failed to prepare INSERT for speed in archive DB"
	)

	stmts.devices = assert(
		adb:prepare("INSERT INTO devices (ts, device_count) VALUES (?, ?);"),
		"Failed to prepare INSERT for devices in archive DB"
	)

	archive_dbs[year] = adb
	archive_stmts[year] = stmts

	return adb, stmts
end

-- Move all rows from table `tbl` whose year is not equal to CURRENT_YEAR into archives
local function move_table(tbl)
	local stmt_key
	if tbl == "ping" then
		stmt_key = "ping"
	elseif tbl == "speed" then
		stmt_key = "speed"
	elseif tbl == "devices" then
		stmt_key = "devices"
	else
		error("Unsupported table: " .. tostring(tbl))
	end

	-- Select all rows that are NOT in the current year
	local select_sql = string.format(
		[[
    SELECT *
    FROM %s
    WHERE CAST(strftime('%%Y', ts, 'unixepoch', 'localtime') AS INTEGER) <> %d
  ]],
		tbl,
		CURRENT_YEAR
	)

	-- First pass: copy rows into archive DBs
	for row in live_db:nrows(select_sql) do
		local ts = row.ts
		local year = tonumber(os.date("%Y", ts))

		local _, stmts = get_archive_db_and_stmts(year)
		local stmt = stmts[stmt_key]
		assert(stmt, "Missing prepared statement for table " .. tbl .. " in year " .. year)

		if tbl == "ping" then
			-- Columns: ts, host, rtt_ms, packet_loss
			stmt:reset()
			assert(
				stmt:bind_values(row.ts, row.host, row.rtt_ms, row.packet_loss) == sqlite3.OK,
				"bind_values failed for ping"
			)
			assert(stmt:step() == sqlite3.DONE, "INSERT into archive ping failed")
		elseif tbl == "speed" then
			-- Columns: ts, download_mbps, upload_mbps
			stmt:reset()
			assert(
				stmt:bind_values(row.ts, row.download_mbps, row.upload_mbps) == sqlite3.OK,
				"bind_values failed for speed"
			)
			assert(stmt:step() == sqlite3.DONE, "INSERT into archive speed failed")
		elseif tbl == "devices" then
			-- Columns: ts, device_count
			stmt:reset()
			assert(stmt:bind_values(row.ts, row.device_count) == sqlite3.OK, "bind_values failed for devices")
			assert(stmt:step() == sqlite3.DONE, "INSERT into archive devices failed")
		end
	end

	-- Second pass: delete those rows from the live DB
	local delete_sql = string.format(
		[[
    DELETE FROM %s
    WHERE CAST(strftime('%%Y', ts, 'unixepoch', 'localtime') AS INTEGER) <> %d
  ]],
		tbl,
		CURRENT_YEAR
	)

	assert(
		live_db:exec("BEGIN; " .. delete_sql .. "; COMMIT;") == sqlite3.OK,
		"Delete failed from live DB for table: " .. tbl
	)
end

-- Run rotation for each table
move_table("ping")
move_table("speed")
move_table("devices")

-- Reclaim space in live DB
live_db:exec("VACUUM;")

-- Finalize statements and close DBs
for _, stmts in pairs(archive_stmts) do
	if stmts.ping then
		stmts.ping:finalize()
	end
	if stmts.speed then
		stmts.speed:finalize()
	end
	if stmts.devices then
		stmts.devices:finalize()
	end
end

for _, db in pairs(archive_dbs) do
	db:close()
end

live_db:close()

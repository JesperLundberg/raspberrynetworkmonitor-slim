#!/usr/bin/env luajit
-- netmon_rotate.lua
-- Export rows older than RETENTION_DAYS to one CSV per table in ARCHIVE_DIR,
-- then delete them so the tmpfs-backed database stays bounded.

local sqlite3 = require("lsqlite3")
local config = require("netmon_config")
local utils = require("netmon_utils")

local TABLES = { "ping", "speed", "devices" }

local function csv_field(v)
	if v == nil then
		return ""
	end
	local s = tostring(v)
	if s:find('[,"\n]') then
		s = '"' .. s:gsub('"', '""') .. '"'
	end
	return s
end

local function table_exists(db, name)
	return utils.fetch_one(db, "SELECT 1 AS ok FROM sqlite_master WHERE type = 'table' AND name = ?;", name) ~= nil
end

-- Export old rows of one table. Returns false when there is nothing to archive.
local function archive_table(db, name, cutoff_ts)
	local archive_path = ("%s/netmon_%s_%s.csv"):format(config.ARCHIVE_DIR, name, os.date("!%Y%m%d"))

	-- `name` comes from the fixed TABLES list above, never from input.
	local stmt = assert(db:prepare(("SELECT * FROM %s WHERE ts < ? ORDER BY ts;"):format(name)), db:errmsg())
	stmt:bind_values(cutoff_ts)

	local names = stmt:get_names()
	local lines = { table.concat(names, ",") }
	for row in stmt:rows() do
		local fields = {}
		for i = 1, #names do
			fields[i] = csv_field(row[i])
		end
		lines[#lines + 1] = table.concat(fields, ",")
	end
	stmt:finalize()

	if #lines == 1 then
		return false
	end

	-- Append, so a second run on the same day does not clobber earlier output.
	-- The header is only written when the file is new.
	local existing = io.open(archive_path, "r")
	if existing then
		existing:close()
		table.remove(lines, 1)
	end
	local f = assert(io.open(archive_path, "a"))
	assert(f:write(table.concat(lines, "\n"), "\n"))
	assert(f:close())

	-- Only delete after the archive has been written successfully.
	local del = assert(db:prepare(("DELETE FROM %s WHERE ts < ?;"):format(name)), db:errmsg())
	del:bind_values(cutoff_ts)
	local rc = del:step()
	del:finalize()
	assert(rc == sqlite3.DONE, "delete failed: " .. db:errmsg())
	return true
end

local function main()
	utils.ensure_dir(config.ARCHIVE_DIR)
	local db = utils.open_db(config.DB_PATH)

	local cutoff_ts = os.time() - config.RETENTION_DAYS * 86400
	local removed = false
	for _, name in ipairs(TABLES) do
		if table_exists(db, name) and archive_table(db, name, cutoff_ts) then
			removed = true
		end
	end

	if removed then
		db:exec("VACUUM;")
	end
	db:close()
end

main()

local sqlite3 = require("lsqlite3")
local config = require("netmon_config")

local M = {}

-- Ensure that a directory exists.
function M.ensure_dir(path)
	os.execute(string.format('mkdir -p "%s"', path))
end

-- Run shell command and capture stdout.
function M.run_cmd(cmd)
	local f = io.popen(cmd, "r")
	if not f then
		return ""
	end
	local result = f:read("*a") or ""
	f:close()

	-- trim trailing whitespace (parentheses drop gsub's second return value)
	return (result:gsub("%s+$", ""))
end

-- Open SQLite database with busy timeout.
-- Jobs are staggered, but the weekly rotate and hourly backup can still overlap them.
function M.open_db(path)
	local db, _, err = sqlite3.open(path or config.DB_PATH)
	assert(db, "Failed to open database: " .. tostring(err or path or config.DB_PATH))
	db:busy_timeout(5000)
	return db
end

-- Fetch the first row of a query with bound parameters (or nil if no rows).
function M.fetch_one(db, sql, ...)
	local stmt = assert(db:prepare(sql), "prepare failed: " .. db:errmsg())
	stmt:bind_values(...)
	local row
	for r in stmt:nrows() do
		row = r
		break
	end
	stmt:finalize()
	return row
end

-- Write a file atomically so readers never see a partial file.
function M.write_atomic(path, content)
	local tmp = path .. ".tmp"
	local f = assert(io.open(tmp, "w"))
	assert(f:write(content))
	assert(f:close())
	assert(os.rename(tmp, path))
end

return M

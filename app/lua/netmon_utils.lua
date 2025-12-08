local sqlite3 = require("lsqlite3")
local config = require("netmon_config")

local M = {}

--Ensure that a directory exists (uses `mkdir -p` under the hood).
function M.ensure_dir(path)
	-- Simple and good enough for this use case
	os.execute(string.format('mkdir -p "%s"', path))
end

--Run shell command and capture its entire stdout.
function M.run_cmd(cmd)
	local f = io.popen(cmd, "r")
	if not f then
		return ""
	end
	local out = f:read("*a") or ""
	f:close()
	return out
end

--Open a SQLite database with a busy timeout.
function M.open_db(path)
	local db, err = sqlite3.open(path or config.DB_PATH)
	assert(db, "Failed to open database: " .. (err or path or config.DB_PATH))
	db:busy_timeout(2000)
	return db
end

--Fetch a single row from a SQL query (or nil if no rows).
function M.fetch_one(db, sql)
	-- Create an iterator...
	local iter = db:nrows(sql)
	-- ...and call it once to get one (or nil)
	return iter()
end

return M

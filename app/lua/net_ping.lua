#!/usr/bin/env luajit

local sqlite3 = require("lsqlite3")
local utils = require("netmon_utils")
local config = require("netmon_config")
local parse = require("netmon_parse")

-- Ping a host and parse average RTT (nil if no reply) and packet loss.
local function ping_host(host)
	-- -W bounds each reply wait so a dead link cannot stall the job.
	local out = utils.run_cmd(string.format("ping -n -c 4 -W 2 %s 2>/dev/null", host))
	return parse.parse_ping(out)
end

local function open_db()
	utils.ensure_dir(config.DB_DIR)
	local db = utils.open_db(config.DB_PATH)
	local rc = db:exec([[
    CREATE TABLE IF NOT EXISTS ping (
      ts          INTEGER NOT NULL,
      host        TEXT    NOT NULL,
      rtt_ms      REAL,
      packet_loss REAL
    );
    CREATE INDEX IF NOT EXISTS idx_ping_ts ON ping(ts);
  ]])
	assert(rc == sqlite3.OK, "Failed to create ping table: " .. db:errmsg())
	return db
end

local function insert_ping(db, ts, host, rtt_ms, packet_loss)
	local stmt = assert(db:prepare("INSERT INTO ping (ts, host, rtt_ms, packet_loss) VALUES (?, ?, ?, ?);"), db:errmsg())
	assert(stmt:bind_values(ts, host, rtt_ms, packet_loss) == sqlite3.OK, "bind failed: " .. db:errmsg())
	local rc = stmt:step()
	stmt:finalize()
	assert(rc == sqlite3.DONE, "INSERT into ping failed: " .. db:errmsg())
end

local function main()
	local ts = os.time()
	local db = open_db()

	for _, host in ipairs(config.PING_HOSTS) do
		-- A failed ping is stored as a NULL rtt so the plot shows a gap, not a drop to 0.
		local rtt, loss = ping_host(host)
		insert_ping(db, ts, host, rtt, loss)
		io.stdout:write(string.format("ping %s: rtt=%s loss=%.1f%%\n", host, rtt and string.format("%.2f ms", rtt) or "n/a", loss))
	end

	db:close()
end

main()

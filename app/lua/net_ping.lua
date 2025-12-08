#!/usr/bin/env luajit

local sqlite3 = require("lsqlite3")
local utils = require("netmon_utils")
local config = require("netmon_config")

local DB_PATH = config.DB_PATH

-- Parse ping output for avg RTT (ms) and packet loss (%)
local function parse_ping_output(output)
	if not output or output == "" then
		return 0.0, 100.0
	end

	-- packet loss
	local loss = output:match("(%d+)%%[%s%-]+packet loss") or output:match("(%d+)%%[%s%-]+loss")
	loss = tonumber(loss) or 0.0

	-- avg RTT: handle both "rtt" and "round-trip" variants
	local avg = output:match("rtt [^=]+= %d+%.?%d*/([%d%.]+)/")
		or output:match("round%-trip [^=]+= %d+%.?%d*/([%d%.]+)/")
	avg = tonumber(avg) or 0.0

	return avg, loss
end

--Ping a host and parse average RTT and packet loss.
local function ping_host(host)
	local cmd = string.format("ping -n -c 4 %s 2>/dev/null", host)
	local out = utils.run_cmd(cmd)
	local rtt, loss = parse_ping_output(out)
	return rtt, loss
end

--Open the ping table in the main database.
local function open_db()
	local db = utils.open_db(DB_PATH)
	local ok, exec_err = db:exec([[
    CREATE TABLE IF NOT EXISTS ping (
      ts          INTEGER NOT NULL,
      host        TEXT    NOT NULL,
      rtt_ms      REAL,
      packet_loss REAL
    );
  ]])
	assert(ok == sqlite3.OK, "Failed to create ping table: " .. tostring(exec_err))
	return db
end

--Insert ping into the database
local function insert_ping(db, ts, host, rtt_ms, packet_loss)
	local stmt = db:prepare("INSERT INTO ping (ts, host, rtt_ms, packet_loss) VALUES (?, ?, ?, ?);")
	assert(stmt, "Failed to prepare INSERT into ping")
	stmt:bind_values(ts, host, rtt_ms, packet_loss)
	assert(stmt:step() == sqlite3.DONE, "INSERT into ping failed")
	stmt:finalize()
end

local ts = os.time()
local db = open_db()

local hosts = { "1.1.1.1", "8.8.8.8" }

for _, host in ipairs(hosts) do
	local rtt, loss = ping_host(host)
	insert_ping(db, ts, host, rtt, loss)
	io.stdout:write(string.format("ping %s: rtt=%.2f ms loss=%.1f%%\n", host, rtt, loss))
end

db:close()

#!/usr/bin/env luajit

local utils = require("netmon_utils")
local config = require("netmon_config")
local parse = require("netmon_parse")

-- Ping a host and parse average RTT (nil if no reply) and packet loss.
local function ping_host(host)
	-- -W bounds each reply wait so a dead link cannot stall the job. No -n: busybox
	-- ping does not accept it, and hosts are IP addresses anyway.
	local out = utils.run_cmd(string.format("ping -c 4 -W 2 %s 2>/dev/null", host))
	return parse.parse_ping(out)
end

local SCHEMA = [[
    CREATE TABLE IF NOT EXISTS ping (
      ts          INTEGER NOT NULL,
      host        TEXT    NOT NULL,
      rtt_ms      REAL,
      packet_loss REAL
    );
    CREATE INDEX IF NOT EXISTS idx_ping_ts ON ping(ts);
  ]]

local function main()
	local ts = os.time()
	local db = utils.open_db(config.DB_PATH, SCHEMA)

	for _, host in ipairs(config.PING_HOSTS) do
		-- A failed ping is stored as a NULL rtt so the plot shows a gap, not a drop to 0.
		local rtt, loss = ping_host(host)
		utils.insert(db, "INSERT INTO ping (ts, host, rtt_ms, packet_loss) VALUES (?, ?, ?, ?);", ts, host, rtt, loss)
		io.stdout:write(string.format("ping %s: rtt=%s loss=%.1f%%\n", host, rtt and string.format("%.2f ms", rtt) or "n/a", loss))
	end

	db:close()
end

main()

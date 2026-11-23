-- Pure parsers for command output, kept free of I/O so they can be tested.
local M = {}

-- Parse `ping` output. Returns avg RTT in ms (nil if no reply) and packet loss in %.
-- Handles iputils ("rtt min/avg/max/mdev = ...") and busybox ("round-trip min/avg/max = ...").
function M.parse_ping(output)
	if not output or output == "" then
		return nil, 100.0
	end

	local loss = output:match("([%d%.]+)%%[%s%-]+packet loss")
	local avg = output:match("rtt [^=]+= [%d%.]+/([%d%.]+)/")
		or output:match("round%-trip [^=]+= [%d%.]+/([%d%.]+)/")

	-- Output without a summary line means ping itself failed.
	return tonumber(avg), tonumber(loss) or 100.0
end

-- Parse the {"bytes":N,"time":T} document written by curl -w. Missing fields are 0.
function M.parse_json_bytes_time(s)
	local b = (s or ""):match('"bytes"%s*:%s*(%d+)')
	local t = (s or ""):match('"time"%s*:%s*([%d%.]+)')
	return tonumber(b) or 0, tonumber(t) or 0.0
end

-- Count unique IPs in arp-scan output. Header, footer and summary lines are ignored.
function M.count_arp_scan(output)
	local seen, count = {}, 0
	for line in (output or ""):gmatch("[^\r\n]+") do
		local ip = line:match("^(%d+%.%d+%.%d+%.%d+)%s+[%x:]+%s+")
		if ip and not seen[ip] then
			seen[ip] = true
			count = count + 1
		end
	end
	return count
end

return M

-- Run from the app/ directory: luajit tests/test_parse.lua
package.path = "lua/?.lua;" .. package.path

local parse = require("netmon_parse")

local function eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg, tostring(b), tostring(a)), 2)
	end
end

-- iputils
local rtt, loss = parse.parse_ping([[
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
--- 1.1.1.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3004ms
rtt min/avg/max/mdev = 9.100/10.250/12.000/1.100 ms]])
eq(rtt, 10.25, "iputils rtt")
eq(loss, 0, "iputils loss")

-- busybox
rtt, loss = parse.parse_ping([[
--- 8.8.8.8 ping statistics ---
4 packets transmitted, 3 packets received, 25% packet loss
round-trip min/avg/max = 11.000/12.500/14.000 ms]])
eq(rtt, 12.5, "busybox rtt")
eq(loss, 25, "busybox loss")

-- Total loss: no rtt line, so rtt is nil (stored as NULL, not 0)
rtt, loss = parse.parse_ping("4 packets transmitted, 0 received, 100% packet loss, time 3070ms")
eq(rtt, nil, "total loss rtt")
eq(loss, 100, "total loss")

-- Empty or garbage output counts as failure
rtt, loss = parse.parse_ping("")
eq(rtt, nil, "empty rtt")
eq(loss, 100, "empty loss")
rtt, loss = parse.parse_ping("ping: bad address")
eq(loss, 100, "garbage loss")

-- curl -w document
local b, t = parse.parse_json_bytes_time('{"bytes":10000000,"time":2.5}')
eq(b, 10000000, "bytes")
eq(t, 2.5, "time")
b, t = parse.parse_json_bytes_time("")
eq(b, 0, "empty bytes")
eq(t, 0, "empty time")

-- arp-scan: duplicates (DUP replies) counted once, non-host lines ignored
local n = parse.count_arp_scan(table.concat({
	"Interface: eth0, type: EN10MB, MAC: aa:bb:cc:dd:ee:ff, IPv4: 192.168.1.5",
	"Starting arp-scan 1.10.0 with 256 hosts",
	"192.168.1.1\t7c:77:16:12:8a:a8\tSome Vendor",
	"192.168.1.20\t00:11:22:33:44:55\tOther Vendor",
	"192.168.1.20\t00:11:22:33:44:55\tOther Vendor (DUP: 2)",
	"",
	"3 packets received by filter, 0 packets dropped by kernel",
	"Ending arp-scan 1.10.0: 256 hosts scanned. 2 responded",
}, "\n"))
eq(n, 2, "arp-scan count")
eq(parse.count_arp_scan(""), 0, "arp-scan empty")

print("all parse tests passed")

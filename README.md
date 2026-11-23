# Network Monitor (slim)

Lightweight network monitor for a Raspberry Pi. Cron jobs in the `netmon`
container measure ping, internet speed and LAN device count into SQLite, render
PNG plots with gnuplot, and write a `status.json`. The `web` container (nginx)
serves a static page that shows them.

## Run

```sh
docker compose up -d --build
```

Open `http://<host>:8080/network.html`.

## How it works

| Job | Schedule | What |
| --- | --- | --- |
| `net_ping.lua` | every 5 min | Ping 1.1.1.1 and 8.8.8.8 (RTT, packet loss) |
| `net_speed.lua` | every 10 min (minute 2, 12, ...) | Download/upload sample with curl |
| `net_devices.lua` | every 5 min (minute 1, 6, ...) | Count devices on the LAN with arp-scan |
| `update_status.lua` | after each job above | Write `status.json` for the status cards |
| `make_plots.sh` | every 5 min (minute 3, 8, ...) | Render the 24h plots (desktop + mobile sizes) |
| `backup.sh` | hourly | Copy the tmpfs DB to `./data/netmon.db` |
| `netmon_rotate.lua` | weekly | Archive rows older than `RETENTION_DAYS` to CSV in `./data/archive`, then delete them |

- The database lives on a tmpfs (to spare the SD card). It is restored from
  `./data/netmon.db` on start and backed up hourly and on `docker stop`.
  A hard power loss loses up to an hour of samples.
- A failed ping, speed test or measurement is stored as NULL, so plots show a
  gap instead of a drop to 0. A device scan that finds nothing is skipped.
- Timestamps are epoch seconds (UTC) and shown in local time (`TZ` is set in the
  Dockerfile and compose file; change both together. busybox `crond` passes
  that environment on to the jobs).
- Job output goes to the container's stdout: `docker logs netmon`.
- The container has a healthcheck: it is unhealthy if `status.json` is older
  than 10 minutes.

## Configuration

- `app/lua/netmon_config.lua`: paths, ping hosts and `RETENTION_DAYS`. The
  ping hosts are also written in the ping filters in `app/make_plots.sh`.
- `app/make_plots.sh`: `WINDOW_HOURS` and the list of plots.
- `app/crontab`: schedules.
- `NETMON_IFACE` (environment): network interface for arp-scan. Defaults to
  `eth0`, then `wlan0`.

## Reset history

```sh
docker compose down
rm data/netmon.db
docker compose up -d
```

## Tests

```sh
cd app && luajit tests/test_parse.lua
```

# Network Monitor (Slim Docker Version)

A small, containerized network monitoring setup that:

- measures ping, speed and device count
- stores everything in a lightweight SQLite database
- generates PNG charts with gnuplot
- serves a simple dashboard via Nginx

## Features

- Ping monitoring (1.1.1.1 and 8.8.8.8)
- Download / upload speed sampling
- LAN device count
- Automatic chart generation (desktop + mobile versions)
- Small JSON status file for quick dashboard rendering
- Clean and minimal HTML dashboard
- Runtime SQLite database lives entirely in RAM (tmpfs)
- Automatic hourly backup ensures persistence without constant disk writes

Charts and status files are temporary and regenerated every cycle.

## Structure

```
app/        → data collection, plotting, cron
  lua/      → measurement scripts
  plots/    → gnuplot configs
  Dockerfile
  crontab

web/        → static dashboard HTML

data/       → persisted backup of netmon.db

docker-compose.yml
```

Two containers:

- **netmon** – runs scripts, writes data, generates charts
- **netmon_web** – serves the dashboard + generated images

A shared Docker volume passes charts/status between them.

## Usage

### Build and start

```bash
docker compose build
docker compose up -d
```

Visit:

```
http://localhost:8080/network.html
```

(Replace `localhost` if hosted elsewhere.)

## Persistence

The live SQLite database is kept in RAM for speed and reduced wear.  
An hourly backup is written to:

```
data/netmon.db
```

On startup, if a backup exists, it is restored automatically.

To reset history:

```bash
docker compose down
rm data/netmon.db
touch data/netmon.db
docker compose up -d
```

## Logs & debugging

```bash
docker logs netmon
docker logs netmon_web
```

Inside the netmon container:

```bash
docker exec -it netmon sh
cat /var/log/cron.log
```

## Notes

- Cron schedules are defined in `app/crontab`.
- All scripts recreate their own tables if needed.
- You can adjust sampling intervals by editing the cron file.
- Works anywhere Docker does.

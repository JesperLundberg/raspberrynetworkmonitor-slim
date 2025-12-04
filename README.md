# Network Monitor (Slim Docker Version)

A small, containerized network monitoring setup that:

- measures ping, speed and device count,
- stores everything in a small SQLite database,
- generates PNG charts with gnuplot,
- and serves a simple dashboard via Nginx.

## Features

- Ping monitoring (latency + packet loss)
- Download / upload speed sampling
- LAN device count
- Automatic chart generation (desktop + mobile versions)
- Small JSON status file for quick dashboard rendering
- Clean and minimal HTML dashboard

Only the SQLite database is persisted; all charts and status files are regenerated.

## Structure

```
app/        → data collection, plotting, cron
  lua/      → measurement scripts
  plots/    → gnuplot configs
  Dockerfile
  crontab
web/        → static dashboard HTML
data/       → netmon.db (persisted)
docker-compose.yml
```

Two containers:

- **netmon** – runs all scripts, writes data, generates charts
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

## Data persistence

The only persistent file is:

```
data/netmon.db
```

You can delete it to reset all history:

```bash
docker compose down
rm data/netmon.db
touch data/netmon.db
docker compose up -d
```

Charts and status files live inside a Docker volume and are regenerated automatically.

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
- No platform assumptions — runs anywhere Docker does.

#!/bin/sh
set -eu

PLOT_DIR="/opt/netmon/plots"
OUT_DIR="/var/www/html/netmon"
mkdir -p "$OUT_DIR"

DB="/opt/netmon/db/netmon.db"

# Single source for the plotted window; titles are derived from it.
WINDOW_HOURS=24
WINDOW="-${WINDOW_HOURS} hours"

# The two ping series are the hosts in netmon_config.lua.
set -- $(luajit -e 'for _, h in ipairs(require("netmon_config").PING_HOSTS) do print(h) end')
HOST_A="$1"
HOST_B="$2"

# Common gnuplot variables; $1 is the size ("W=..; H=..; FONT_SIZE=..").
run_plot() {
  size="$1"
  out="$2"
  title="$3"
  ylab="$4"
  table="$5"
  col="$6"
  color="$7"

  gnuplot -e "$size; PLOT_DIR='$PLOT_DIR'; DB='$DB'; WINDOW='$WINDOW'; OUT='$out'; TITLE='$title'; YLAB='$ylab'; TABLE='$table'; COL='$col'; LINECOLOR='$color'" \
    "$PLOT_DIR/plot_single_sql.gp"
}

# Filters contain single quotes (SQL string literals), so they are passed as
# gnuplot double-quoted strings.
run_plot_two() {
  size="$1"
  out="$2"
  title="$3"
  ylab="$4"
  table="$5"
  col_a="$6"
  col_b="$7"
  filter_a="$8"
  filter_b="$9"
  color_a="${10}"
  color_b="${11}"

  gnuplot -e "$size; PLOT_DIR='$PLOT_DIR'; DB='$DB'; WINDOW='$WINDOW'; OUT='$out'; TITLE='$title'; YLAB='$ylab'; TABLE='$table'; COL_A='$col_a'; COL_B='$col_b'; FILTER_A=\"$filter_a\"; FILTER_B=\"$filter_b\"; LINECOLOR_A='$color_a'; LINECOLOR_B='$color_b'" \
    "$PLOT_DIR/plot_two_sql.gp"
}

# Mobile files get a "_mobile" suffix.
for variant in desktop mobile; do
  if [ "$variant" = "desktop" ]; then
    size="W=1000; H=350; FONT_SIZE=10"
    sfx=""
  else
    size="W=700; H=450; FONT_SIZE=14"
    sfx="_mobile"
  fi

  run_plot_two "$size" "$OUT_DIR/ping${sfx}.png" "Ping RTT (ms) - last ${WINDOW_HOURS}h" "RTT (ms)" \
    "ping" "rtt_ms" "rtt_ms" "host = '$HOST_A'" "host = '$HOST_B'" "#1e66f5" "#40a02b"

  run_plot_two "$size" "$OUT_DIR/speed${sfx}.png" "Internet speed (Mbps) - last ${WINDOW_HOURS}h" "Mbps" \
    "speed" "download_mbps" "upload_mbps" "1" "1" "#dc8a78" "#1e66f5"

  run_plot "$size" "$OUT_DIR/devices${sfx}.png" "Active devices on LAN - last ${WINDOW_HOURS}h" "Device count" \
    "devices" "device_count" "#df8e1d"
done

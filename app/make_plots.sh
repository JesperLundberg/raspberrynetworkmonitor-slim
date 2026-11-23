#!/bin/sh
set -eu

PLOT_DIR="/opt/netmon/plots"
OUT_DIR="/var/www/html/netmon"
mkdir -p "$OUT_DIR"

DB="/opt/netmon/db/netmon.db"

# Single source for the plotted window; titles are derived from it.
WINDOW_HOURS=24
WINDOW="-${WINDOW_HOURS} hours"

run_plot() {
  size="$1"
  plot="$2"
  out="$3"
  title="$4"
  ylab="$5"
  table="$6"
  col="$7"
  color="$8"

  gnuplot -e "PLOT_DIR='$PLOT_DIR'; DB='$DB'; WINDOW='$WINDOW'; OUT='$out'; TITLE='$title'; YLAB='$ylab'; TABLE='$table'; COL='$col'; LINECOLOR='$color'" \
    "$PLOT_DIR/$size" "$PLOT_DIR/$plot"
}

# Filters contain single quotes (SQL string literals), so they are passed as
# gnuplot double-quoted strings.
run_plot_two() {
  size="$1"
  plot="$2"
  out="$3"
  title="$4"
  ylab="$5"
  table="$6"
  col_a="$7"
  col_b="$8"
  filter_a="$9"
  filter_b="${10}"
  color_a="${11}"
  color_b="${12}"

  gnuplot -e "PLOT_DIR='$PLOT_DIR'; DB='$DB'; WINDOW='$WINDOW'; OUT='$out'; TITLE='$title'; YLAB='$ylab'; TABLE='$table'; COL_A='$col_a'; COL_B='$col_b'; FILTER_A=\"$filter_a\"; FILTER_B=\"$filter_b\"; LINECOLOR_A='$color_a'; LINECOLOR_B='$color_b'" \
    "$PLOT_DIR/$size" "$PLOT_DIR/$plot"
}

# Mobile files get a "_mobile" suffix.
for variant in desktop mobile; do
  if [ "$variant" = "desktop" ]; then
    size="size_desktop.gp"
    sfx=""
  else
    size="size_mobile.gp"
    sfx="_mobile"
  fi

  run_plot_two "$size" "plot_two_sql.gp" "$OUT_DIR/ping${sfx}.png" "Ping RTT (ms) - last ${WINDOW_HOURS}h" "RTT (ms)" \
    "ping" "rtt_ms" "rtt_ms" "host = '1.1.1.1'" "host = '8.8.8.8'" "#1e66f5" "#40a02b"

  run_plot_two "$size" "plot_two_sql.gp" "$OUT_DIR/speed${sfx}.png" "Internet speed (Mbps) - last ${WINDOW_HOURS}h" "Mbps" \
    "speed" "download_mbps" "upload_mbps" "1" "1" "#dc8a78" "#1e66f5"

  run_plot "$size" "plot_single_sql.gp" "$OUT_DIR/devices${sfx}.png" "Active devices on LAN - last ${WINDOW_HOURS}h" "Device count" \
    "devices" "device_count" "#df8e1d"
done

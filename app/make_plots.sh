#!/usr/bin/env bash
set -euo pipefail

PLOT_DIR="/opt/netmon/plots"
OUT_DIR="/var/www/html/netmon"

# Ensure output directory exists
mkdir -p "$OUT_DIR"

# Call gnuplot scripts by path
gnuplot "$PLOT_DIR/plot_ping.gnuplot"
gnuplot "$PLOT_DIR/plot_ping_mobile.gnuplot"
gnuplot "$PLOT_DIR/plot_speed.gnuplot"
gnuplot "$PLOT_DIR/plot_speed_mobile.gnuplot"
gnuplot "$PLOT_DIR/plot_devices.gnuplot"
gnuplot "$PLOT_DIR/plot_devices_mobile.gnuplot"

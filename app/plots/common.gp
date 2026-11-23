# Common style/shared settings (Catppuccin Latte-like).
set datafile separator "|"

# Background
set object 1 rectangle from screen 0,0 to screen 1,1 behind \
  fillcolor rgb "#eff1f5" fillstyle solid 1.0

set border lc rgb "#4c4f69"
set grid lc rgb "#ccd0da"
set tics textcolor rgb "#4c4f69"
set key textcolor rgb "#4c4f69"

# Soft zero: always start at 0, autoscale upper bound.
set yrange [0:*]

# The queries return local time as "YYYY-MM-DD HH:MM:SS". gnuplot would show
# raw epoch values (%s) in UTC, so the conversion happens in SQL instead.
set xdata time
set timefmt "%Y-%m-%d %H:%M:%S"
set format x "%H:%M\n%d/%m"

# One label every 4 hours (00:00, 04:00, ...); hourly labels are unreadable.
set xtics 4*3600
set mxtics 4

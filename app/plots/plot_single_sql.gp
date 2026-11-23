# Generic single-series SQLite-backed plot.
# Required vars passed via -e:
#   PLOT_DIR  -> directory holding common.gp
#   W, H      -> image size
#   FONT_SIZE -> font size
#   OUT       -> output png path
#   TITLE     -> plot title
#   YLAB      -> y-axis label
#   TABLE     -> SQLite table name
#   COL       -> SQLite column name
#   DB        -> SQLite db path
#   WINDOW    -> sqlite time modifier, e.g. "-24 hours"
#   LINECOLOR -> line color

load sprintf("%s/common.gp", PLOT_DIR)

set terminal pngcairo size W,H enhanced font sprintf(",%d", FONT_SIZE)
set output OUT

set title TITLE textcolor rgb "#4c4f69"
set ylabel YLAB textcolor rgb "#4c4f69"

# ts is epoch seconds (UTC): filter on it directly and only convert the displayed value.
CMD = sprintf("< sqlite3 -noheader -separator '|' '%s' \"SELECT datetime(ts,'unixepoch','localtime'), %s FROM %s WHERE ts >= CAST(strftime('%%s','now','%s') AS INTEGER) ORDER BY ts;\"", DB, COL, TABLE, WINDOW)
plot CMD using 1:2 with lines lw 2 lc rgb LINECOLOR title ""

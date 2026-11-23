# Generic single-series SQLite-backed plot.
# Required vars passed via -e:
#   PLOT_DIR  -> directory holding common.gp
#   W, H      -> image size (from size_*.gp)
#   OUT       -> output png path
#   TITLE     -> plot title
#   YLAB      -> y-axis label
#   TABLE     -> SQLite table name
#   COL       -> SQLite column name
# Optional vars:
#   DB        -> SQLite db path (default: /opt/netmon/db/netmon.db)
#   WINDOW    -> sqlite time modifier (default: -24 hours)
#   FILTER    -> extra SQL condition (default: 1)
#   LINECOLOR -> line color (default: #1e66f5)
#   LW        -> line width (default: 2)

load sprintf("%s/common.gp", PLOT_DIR)

if (!exists("DB")) DB = "/opt/netmon/db/netmon.db"
if (!exists("WINDOW")) WINDOW = "-24 hours"
if (!exists("FILTER")) FILTER = "1"
if (!exists("LINECOLOR")) LINECOLOR = "#1e66f5"
if (!exists("LW")) LW = 2
if (!exists("FONT_SIZE")) FONT_SIZE = 10

set terminal pngcairo size W,H enhanced font sprintf(",%d", FONT_SIZE)
set output OUT

set title TITLE textcolor rgb "#4c4f69"
set ylabel YLAB textcolor rgb "#4c4f69"

# ts is epoch seconds (UTC): filter on it directly and only convert the displayed value.
CMD = sprintf("< sqlite3 -noheader -separator '|' '%s' \"SELECT datetime(ts,'unixepoch','localtime'), %s FROM %s WHERE ts >= CAST(strftime('%%s','now','%s') AS INTEGER) AND (%s) ORDER BY ts;\"", DB, COL, TABLE, WINDOW, FILTER)
plot CMD using 1:2 with lines lw LW lc rgb LINECOLOR title ""

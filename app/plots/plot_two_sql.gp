# Generic two-series SQLite-backed plot. Both series read the same table, so a
# series is either a different column (speed) or a different row filter (ping).
# Required vars passed via -e:
#   PLOT_DIR  -> directory holding common.gp
#   W, H      -> image size (from size_*.gp)
#   OUT       -> output png path
#   TITLE     -> plot title
#   YLAB      -> y-axis label
#   TABLE     -> SQLite table name
#   COL_A     -> first SQLite column name
#   COL_B     -> second SQLite column name
# Optional vars:
#   DB          -> SQLite db path (default: /opt/netmon/db/netmon.db)
#   WINDOW      -> sqlite time modifier (default: -24 hours)
#   FILTER_A/B  -> extra SQL condition per series (default: 1)
#   LINECOLOR_A -> color for first line (default: #1e66f5)
#   LINECOLOR_B -> color for second line (default: #40a02b)
#   LW          -> line width (default: 2)
#   LABEL_A     -> legend label for first line (default: no key)
#   LABEL_B     -> legend label for second line (default: no key)

load sprintf("%s/common.gp", PLOT_DIR)

if (!exists("DB")) DB = "/opt/netmon/db/netmon.db"
if (!exists("WINDOW")) WINDOW = "-24 hours"
if (!exists("FILTER_A")) FILTER_A = "1"
if (!exists("FILTER_B")) FILTER_B = "1"
if (!exists("LINECOLOR_A")) LINECOLOR_A = "#1e66f5"
if (!exists("LINECOLOR_B")) LINECOLOR_B = "#40a02b"
if (!exists("LW")) LW = 2
if (!exists("LABEL_A")) LABEL_A = ""
if (!exists("LABEL_B")) LABEL_B = ""
if (!exists("FONT_SIZE")) FONT_SIZE = 10

set terminal pngcairo size W,H enhanced font sprintf(",%d", FONT_SIZE)
set output OUT

set title TITLE textcolor rgb "#4c4f69"
set ylabel YLAB textcolor rgb "#4c4f69"

# ts is epoch seconds (UTC): filter on it directly and only convert the displayed value.
QUERY = "< sqlite3 -noheader -separator '|' '%s' \"SELECT datetime(ts,'unixepoch','localtime'), %s FROM %s WHERE ts >= CAST(strftime('%%s','now','%s') AS INTEGER) AND (%s) ORDER BY ts;\""
CMD_A = sprintf(QUERY, DB, COL_A, TABLE, WINDOW, FILTER_A)
CMD_B = sprintf(QUERY, DB, COL_B, TABLE, WINDOW, FILTER_B)

plot \
  CMD_A using 1:2 with lines lw LW lc rgb LINECOLOR_A title LABEL_A, \
  CMD_B using 1:2 with lines lw LW lc rgb LINECOLOR_B title LABEL_B

# Generic two-series SQLite-backed plot. Both series read the same table, so a
# series is either a different column (speed) or a different row filter (ping).
# Required vars passed via -e:
#   PLOT_DIR    -> directory holding common.gp
#   W, H        -> image size
#   FONT_SIZE   -> font size
#   OUT         -> output png path
#   TITLE       -> plot title
#   YLAB        -> y-axis label
#   TABLE       -> SQLite table name
#   COL_A/B     -> SQLite column name per series
#   FILTER_A/B  -> SQL condition per series ("1" for all rows)
#   LINECOLOR_A/B -> line color per series
#   DB          -> SQLite db path
#   WINDOW      -> sqlite time modifier, e.g. "-24 hours"

load sprintf("%s/common.gp", PLOT_DIR)

set terminal pngcairo size W,H enhanced font sprintf(",%d", FONT_SIZE)
set output OUT

set title TITLE textcolor rgb "#4c4f69"
set ylabel YLAB textcolor rgb "#4c4f69"

# ts is epoch seconds (UTC): filter on it directly and only convert the displayed value.
QUERY = "< sqlite3 -noheader -separator '|' '%s' \"SELECT datetime(ts,'unixepoch','localtime'), %s FROM %s WHERE ts >= CAST(strftime('%%s','now','%s') AS INTEGER) AND (%s) ORDER BY ts;\""
CMD_A = sprintf(QUERY, DB, COL_A, TABLE, WINDOW, FILTER_A)
CMD_B = sprintf(QUERY, DB, COL_B, TABLE, WINDOW, FILTER_B)

plot \
  CMD_A using 1:2 with lines lw 2 lc rgb LINECOLOR_A title "", \
  CMD_B using 1:2 with lines lw 2 lc rgb LINECOLOR_B title ""

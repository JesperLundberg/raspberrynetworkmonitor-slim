set terminal pngcairo size 1000,350 enhanced font ",10"
set output "/var/www/html/netmon/ping.png"

set datafile separator "|"

# Light Catppuccin Latte background
set object 1 rectangle from screen 0,0 to screen 1,1 behind \
    fillcolor rgb "#eff1f5" fillstyle solid 1.0

set border lc rgb "#4c4f69"
set grid lc rgb "#ccd0da"
set tics textcolor rgb "#4c4f69"

set xdata time
set timefmt "%s"
set format x "%H:%M\n%d-%m"

# Soft min at 0
set yrange [0:*]

# Last 24 hours
now = time(0)
dayago = now - 24*3600
set xrange [dayago:now]

set title "Ping RTT (ms)" tc rgb "#4c4f69"
set xlabel "Time" tc rgb "#4c4f69"
set ylabel "RTT (ms)" tc rgb "#4c4f69"

plot "< sqlite3 /opt/netmon/db/netmon.db\"SELECT ts, rtt_ms FROM ping WHERE host='1.1.1.1' ORDER BY ts;\"" \
        using 1:2 with lines lw 2 lc rgb "#1e66f5" notitle, \
     "< sqlite3 /opt/netmon/db/netmon.db\"SELECT ts, rtt_ms FROM ping WHERE host='8.8.8.8' ORDER BY ts;\"" \
        using 1:2 with lines lw 2 lc rgb "#40a02b" notitle

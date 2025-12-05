set terminal pngcairo size 700,450 enhanced font ",14"
set output "/var/www/html/netmon/devices_mobile.png"

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

set yrange [0:*]

now = time(0)
dayago = now - 24*3600
set xrange [dayago:now]

set title "Active devices on LAN" tc rgb "#4c4f69"
set xlabel "Time" tc rgb "#4c4f69"
set ylabel "Device count" tc rgb "#4c4f69"

plot "< sqlite3 /opt/netmon/db/netmon.db\"SELECT ts, device_count FROM devices ORDER BY ts;\"" \
        using 1:2 with lines lw 2 lc rgb "#df8e1d" notitle

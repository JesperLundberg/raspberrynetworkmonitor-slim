FROM alpine:latest

ENV TZ=Europe/Stockholm
ENV LUA_PATH="/opt/netmon/lua/?.lua;/opt/netmon/lua/?/init.lua;;"

# busybox supplies crond, ping, dd and date; httpd is in busybox-extras; arp-scan and curl
# are separate packages.
# lsqlite3 and dkjson are luarocks, not apk packages. Alpine ships one luarocks package
# per Lua version (luarocks5.1, binary luarocks-5.1). Rocks install under /usr/local,
# which LuaJIT searches by default. Build tooling is removed in the same layer.
# sqlite-libs must be explicit: lsqlite3.so links against it, and otherwise it is only
# pulled in by sqlite-dev and removed together with the build group.
RUN apk add --no-cache luajit sqlite sqlite-libs gnuplot font-dejavu arp-scan curl ca-certificates tzdata busybox-extras \
    && apk add --no-cache --virtual .build luarocks5.1 build-base luajit-dev sqlite-dev unzip \
    && luarocks-5.1 install lsqlite3 LUA_INCDIR=/usr/include/luajit-2.1 \
    && luarocks-5.1 install dkjson \
    && apk del .build

WORKDIR /opt/netmon

COPY lua ./lua
COPY plots ./plots
COPY --chmod=755 make_plots.sh backup.sh entrypoint.sh ./
COPY network.html /var/www/html/network.html
# busybox crond reads /etc/crontabs/<user>; the file must not be group/world writable.
COPY --chmod=600 crontab /etc/crontabs/root

RUN chmod +x lua/*.lua && mkdir -p /var/www/html/netmon

CMD ["/opt/netmon/entrypoint.sh"]

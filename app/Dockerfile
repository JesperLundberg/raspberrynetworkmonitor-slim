FROM alpine:latest

ENV TZ=Europe/Stockholm
ENV LUA_PATH="/opt/netmon/lua/?.lua;/opt/netmon/lua/?/init.lua;;"

# busybox supplies crond, ping, dd and date; arp-scan and curl are separate packages.
# lsqlite3 and dkjson are luarocks, not apk packages. Alpine ships one luarocks package
# per Lua version (luarocks5.1, binary luarocks-5.1). Rocks install under /usr/local,
# which LuaJIT searches by default. Build tooling is removed in the same layer.
# sqlite-libs must be explicit: lsqlite3.so links against it, and otherwise it is only
# pulled in by sqlite-dev and removed together with the build group.
RUN apk add --no-cache luajit sqlite sqlite-libs gnuplot font-dejavu arp-scan curl ca-certificates tzdata \
    && apk add --no-cache --virtual .build luarocks5.1 build-base luajit-dev sqlite-dev unzip \
    && luarocks-5.1 install lsqlite3 LUA_INCDIR=/usr/include/luajit-2.1 \
    && luarocks-5.1 install dkjson \
    && apk del .build

WORKDIR /opt/netmon

COPY lua ./lua
COPY plots ./plots
COPY tests ./tests
COPY make_plots.sh backup.sh ./
# busybox crond reads /etc/crontabs/<user>; the file must not be group/world writable.
COPY crontab /etc/crontabs/root
COPY entrypoint.sh ./entrypoint.sh

RUN chmod +x /opt/netmon/make_plots.sh \
    && chmod +x /opt/netmon/backup.sh \
    && chmod +x /opt/netmon/lua/*.lua \
    && chmod 0600 /etc/crontabs/root \
    && mkdir -p /var/www/html/netmon \
    && mkdir -p /opt/netmon/backups \
    && mkdir -p /opt/netmon/archive \
    && chmod +x /opt/netmon/entrypoint.sh

CMD ["/opt/netmon/entrypoint.sh"]

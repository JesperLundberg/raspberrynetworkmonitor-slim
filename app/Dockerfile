FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Stockholm
# Set lua path so the lua modules are found
ENV LUA_PATH="/opt/netmon/lua/?.lua;/opt/netmon/lua/?/init.lua;;"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        luajit \
        luarocks \
        sqlite3 \
        gnuplot-nox \
        curl \
        arp-scan \
        iputils-ping \
        cron \
        ca-certificates \
        tzdata \
        build-essential \
        libsqlite3-dev && \
    luarocks --lua-version=5.1 install lsqlite3 && \
    luarocks --lua-version=5.1 install dkjson && \
    apt-get remove -y build-essential libsqlite3-dev && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt/netmon

COPY lua ./lua
COPY plots ./plots
COPY make_plots.sh ./
COPY crontab /etc/cron.d/netmon
COPY entrypoint.sh ./entrypoint.sh

RUN chmod +x /opt/netmon/make_plots.sh \
    && chmod +x /opt/netmon/lua/*.lua \
    && chmod 0644 /etc/cron.d/netmon \
    && mkdir -p /var/www/html/netmon \
    && mkdir -p /opt/netmon/backups \
    && chmod +x /opt/netmon/entrypoint.sh \
    && touch /var/log/cron.log

CMD ["/opt/netmon/entrypoint.sh"]

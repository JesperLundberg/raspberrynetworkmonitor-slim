FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Stockholm

# Install tools and build dependencies
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
    # Install lsqlite3 via LuaRocks for Lua 5.1 ABI (used by LuaJIT)
    luarocks --lua-version=5.1 install lsqlite3 && \
    # Clean up
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Main working directory inside container
WORKDIR /opt/netmon

# Copy Lua scripts into /opt/netmon/lua
COPY lua ./lua

# Copy gnuplot scripts into /opt/netmon/plots
COPY plots ./plots

# Copy shell script and cron config
COPY make_plots.sh ./
COPY crontab /etc/cron.d/netmon

# Permissions
RUN chmod +x /opt/netmon/make_plots.sh \
    && chmod +x /opt/netmon/lua/*.lua \
    && chmod 0644 /etc/cron.d/netmon \
    && mkdir -p /var/www/html/netmon \
    && touch /var/log/cron.log

# Run cron in foreground so container stays alive
CMD ["cron", "-f"]

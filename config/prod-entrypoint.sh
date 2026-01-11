#!/bin/bash
set -e

cd /home/frappe/frappe-bench

# Configure bench on first run
if [ ! -f sites/common_site_config.json ] || [ ! -s sites/common_site_config.json ]; then
  echo '{}' > sites/common_site_config.json
fi

bench set-config -g db_host "${DB_HOST:-db}"
bench set-config -gp db_port "${DB_PORT:-3306}"
bench set-config -g redis_cache "${REDIS_CACHE:-redis://redis:6379}"
bench set-config -g redis_queue "${REDIS_QUEUE:-redis://redis:6379}"
bench set-config -g redis_socketio "${REDIS_QUEUE:-redis://redis:6379}"
bench set-config -gp socketio_port "${SOCKETIO_PORT:-9000}"

# Generate apps.txt from installed apps
ls -1 apps > sites/apps.txt 2>/dev/null || true

# Start all services
exec honcho start -f Procfile

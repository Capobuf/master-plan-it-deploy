#!/bin/bash
# Production entrypoint: configures bench on every start, then launches services.
# The custom app and this script are baked into the image by Dockerfile.frappe.
set -e

cd /home/frappe/frappe-bench

[ -f sites/common_site_config.json ] && [ -s sites/common_site_config.json ] \
  || echo '{}' > sites/common_site_config.json

bench set-config -g db_host "${DB_HOST:-db}"
bench set-config -gp db_port "${DB_PORT:-3306}"
bench set-config -g redis_cache "${REDIS_CACHE:-redis://redis:6379}"
bench set-config -g redis_queue "${REDIS_QUEUE:-redis://redis:6379}"
# Single-Redis setup: socketio shares the same instance as cache.
bench set-config -g redis_socketio "${REDIS_CACHE:-redis://redis:6379}"
bench set-config -gp socketio_port "${SOCKETIO_PORT:-9000}"

ls -1 apps > sites/apps.txt 2>/dev/null || true

exec honcho start -f Procfile

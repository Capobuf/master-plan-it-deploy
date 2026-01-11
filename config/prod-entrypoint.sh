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

# Install custom apps as Python packages (editable mode)
# This ensures modules are importable after bench get-app
for app_dir in apps/*/; do
  app_name=$(basename "$app_dir")
  # Skip frappe and erpnext (already installed in base image)
  if [ "$app_name" != "frappe" ] && [ "$app_name" != "erpnext" ]; then
    if [ -f "$app_dir/setup.py" ] || [ -f "$app_dir/pyproject.toml" ]; then
      echo "Installing $app_name as editable package..."
      pip install -e "$app_dir" --quiet 2>/dev/null || true
    fi
  fi
done

# Start all services
exec honcho start -f Procfile

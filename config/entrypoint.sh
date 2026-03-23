#!/usr/bin/env bash
# Development entrypoint: fixes bind-mount permissions, creates site if missing,
# enables developer_mode, then starts services via Procfile.
set -euo pipefail

export DEV_SERVER=1
export PYTHONPATH="/home/frappe/frappe-bench/apps:${PYTHONPATH:-}"

cd /home/frappe/frappe-bench

# Re-exec as frappe user after fixing permissions on bind-mounted volumes.
if [ "$(id -u)" -eq 0 ] && [ "${RUN_AS_FRAPPE:-0}" != "1" ]; then
  install -d -m 0777 sites logs
  chmod -R 0777 sites logs || true
  export RUN_AS_FRAPPE=1
  exec su -s /bin/bash frappe -c "/home/frappe/frappe-bench/config/entrypoint.sh"
fi

umask 000

[ -f sites/common_site_config.json ] || echo "{}" > sites/common_site_config.json

# Rebuild apps.txt from the apps/ directory.
ls -1 apps > sites/apps.txt
for app_dir in apps/*; do realpath "$app_dir"; done > sites/apps_path.txt

# Point bench at the container services (idempotent).
bench set-config -g db_host db
bench set-config -gp db_port 3306
bench set-config -g redis_cache "redis://redis:6379"
bench set-config -g redis_queue "redis://redis:6379"
bench set-config -g redis_socketio "redis://redis:6379"
bench set-config -gp socketio_port 9000

# Create site on first run.
if [ ! -d "sites/${SITE_NAME}" ]; then
  echo "Creating site ${SITE_NAME}..."
  APPS_ARGS=()
  if [ -n "${INSTALL_APPS:-}" ]; then
    IFS=',' read -ra APPS <<< "${INSTALL_APPS}"
    for app in "${APPS[@]}"; do
      app="$(echo "$app" | xargs)"
      [ -n "$app" ] && APPS_ARGS+=(--install-app "$app")
    done
  fi
  bench new-site \
    --mariadb-user-host-login-scope='%' \
    --admin-password="${ADMIN_PASSWORD}" \
    --db-root-username=root \
    --db-root-password="${DB_ROOT_PASSWORD}" \
    "${APPS_ARGS[@]}" \
    --set-default \
    "${SITE_NAME}"
else
  echo "Site ${SITE_NAME} already exists."
fi

bench --site "${SITE_NAME}" set-config developer_mode 1

[ "${RUN_MIGRATE_ON_START:-0}" = "1" ] && bench --site "${SITE_NAME}" migrate

exec honcho start -f config/Procfile

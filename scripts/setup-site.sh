#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="/home/frappe/frappe-bench"
APP_SOURCE="/workspace/master_plan_it"
export PATH="/home/frappe/.local/bin:/home/frappe/.pyenv/shims:/home/frappe/.pyenv/bin:/home/frappe/.nvm/versions/node/v24.13.0/bin:${PATH}"

required_vars="SITE_NAME FRAPPE_PASSWORD DB_ROOT_PASSWORD"
for var_name in $required_vars; do
  if [ -z "${!var_name:-}" ]; then
    echo "Missing required environment variable: ${var_name}" >&2
    exit 1
  fi
done

wait_for_tcp() {
  host="$1"
  port="$2"
  service_name="$3"
  attempts=60

  until (echo >"/dev/tcp/${host}/${port}") >/dev/null 2>&1; do
    attempts=$((attempts - 1))
    if [ "$attempts" -le 0 ]; then
      echo "Timed out waiting for ${service_name} at ${host}:${port}" >&2
      exit 1
    fi
    sleep 2
  done
}

wait_for_tcp db 3306 MariaDB
wait_for_tcp redis 6379 Redis

if [ ! -d "$APP_SOURCE" ]; then
  echo "Missing mounted app directory: ${APP_SOURCE}" >&2
  exit 1
fi

mkdir -p "${BENCH_DIR}/sites"
if [ -f "${BENCH_DIR}/sites/common_site_config.json" ]; then
  python3 - <<'PY'
import json
from pathlib import Path

config_path = Path("/home/frappe/frappe-bench/sites/common_site_config.json")
config = json.loads(config_path.read_text())
for key in ("db_port", "socketio_port", "webserver_port"):
    if key in config and isinstance(config[key], str) and config[key].isdigit():
        config[key] = int(config[key])
config_path.write_text(json.dumps(config, indent=1, sort_keys=True) + "\n")
PY
fi

if [ ! -d "${BENCH_DIR}/apps/frappe" ]; then
  echo "Initializing Frappe Framework v16 bench..."
  cd /home/frappe
  bench init \
    --skip-redis-config-generation \
    --frappe-branch version-16 \
    --ignore-exist \
    --no-backups \
    frappe-bench
fi

cd "$BENCH_DIR"

if [ ! -d apps/frappe/node_modules ]; then
  (cd apps/frappe && yarn install --check-files)
fi

mkdir -p sites logs apps

if [ -L apps/master_plan_it ]; then
  current_target="$(readlink apps/master_plan_it)"
  if [ "$current_target" != "$APP_SOURCE" ]; then
    rm apps/master_plan_it
    ln -s "$APP_SOURCE" apps/master_plan_it
  fi
elif [ ! -e apps/master_plan_it ]; then
  ln -s "$APP_SOURCE" apps/master_plan_it
elif [ ! -d apps/master_plan_it/master_plan_it ]; then
  echo "apps/master_plan_it exists but does not look like the mounted app." >&2
  exit 1
fi

printf "frappe\nmaster_plan_it\n" >sites/apps.txt

{
  [ -d apps/frappe ] && realpath apps/frappe
  realpath apps/master_plan_it
} >sites/apps_path.txt

bench set-config -g db_host db
bench set-config -gp db_port 3306
bench set-config -g redis_cache redis://redis:6379
bench set-config -g redis_queue redis://redis:6379
bench set-config -g redis_socketio redis://redis:6379
bench set-config -gp socketio_port 9000

printf "y\n" | bench setup procfile
sed -i '/^redis_/d' Procfile

/home/frappe/frappe-bench/env/bin/pip install -e "$APP_SOURCE"

mkdir -p assets
if [ ! -f sites/assets/assets.json ]; then
  bench build --force
fi

if [ ! -f "sites/${SITE_NAME}/site_config.json" ]; then
  echo "Creating site ${SITE_NAME}..."
  bench new-site "$SITE_NAME" \
    --mariadb-user-host-login-scope='%' \
    --admin-password "$FRAPPE_PASSWORD" \
    --db-root-username root \
    --db-root-password "$DB_ROOT_PASSWORD" \
    --set-default
  bench --site "$SITE_NAME" install-app master_plan_it
else
  echo "Site ${SITE_NAME} already exists."
  if ! bench --site "$SITE_NAME" list-apps | awk '{print $1}' | grep -qx master_plan_it; then
    bench --site "$SITE_NAME" install-app master_plan_it
  fi
fi

bench --site "$SITE_NAME" set-config developer_mode 1
bench --site "$SITE_NAME" migrate
if [ "$(bench --site "$SITE_NAME" execute frappe.is_setup_complete)" != "True" ]; then
  bench --site "$SITE_NAME" execute frappe.utils.install.complete_setup_wizard
fi
bench --site "$SITE_NAME" clear-cache

if bench --site "$SITE_NAME" execute master_plan_it.devtools.verify.run; then
  echo "Master Plan IT verification completed."
else
  echo "Master Plan IT verification command is unavailable or failed." >&2
fi

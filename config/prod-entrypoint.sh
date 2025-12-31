#!/usr/bin/env bash
set -euo pipefail

# Sanity check: ci aspettiamo che l'immagine contenga già il bench
if [ ! -d /home/frappe/frappe-bench ]; then
  echo "ERROR: /home/frappe/frappe-bench non trovato nell'immagine." >&2
  exit 1
fi

# Fix permessi volumi (idempotente)
chown -R frappe:frappe /home/frappe/frappe-bench/sites /home/frappe/frappe-bench/logs || true

# Esegui tutto come utente 'frappe'
exec su -s /bin/bash frappe -c '
set -euo pipefail
cd /home/frappe/frappe-bench

bench set-config -g db_host db
bench set-config -gp db_port 3306
bench set-config -g redis_cache "redis://redis:6379"
bench set-config -g redis_queue "redis://redis:6379"
bench set-config -g redis_socketio "redis://redis:6379"
bench set-config -gp socketio_port 9000

bench config dns_multitenant on || true
: > sites/currentsite.txt || true

if [ ! -f sites/apps.txt ]; then
  ls -1 apps > sites/apps.txt
fi
grep -qx "master_plan_it" sites/apps.txt || echo "master_plan_it" >> sites/apps.txt

if [ ! -d "sites/${SITE_NAME}" ]; then
  APPS_ARGS=()
  IFS="," read -ra APPS <<< "${INSTALL_APPS}"
  for app in "${APPS[@]}"; do
    app="$(echo "$app" | xargs)"
    [ -n "$app" ] && APPS_ARGS+=(--install-app "$app")
  done

  bench new-site \
    --mariadb-user-host-login-scope="%" \
    --admin-password="${ADMIN_PASSWORD}" \
    --db-root-username=root \
    --db-root-password="${DB_ROOT_PASSWORD}" \
    "${APPS_ARGS[@]}" \
    "${SITE_NAME}"
fi

if [ "${RUN_MIGRATE_ON_START:-0}" = "1" ]; then
  bench --site "${SITE_NAME}" migrate
  bench --site "${SITE_NAME}" clear-cache
fi

exec honcho start -f config/mpit.Procfile
'

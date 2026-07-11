# master-plan-it-deploy

Docker Compose dev stack for `master_plan_it` on Frappe Framework v16.

## Stack

- `db`: `mariadb:11.8`
- `redis`: `redis:7-alpine`
- `setup`: one-shot bench/site setup
- `frappe`: `frappe/bench:v5.31.0`, runs `bench start`
- `cypress`: test profile only

ERPNext is not installed. The app has no ERPNext runtime dependency.

## Repositories

Expected layout:

```text
master-plan-it-deploy/
master_plan_it/
```

Set `APP_PATH` in `.env` if the app repo has a different path.

## Start

```bash
cp .env.example .env
docker compose up -d
```

Open:

```text
http://mpit.localhost:9797
```

Login:

```text
User: Administrator
Password: FRAPPE_PASSWORD from .env
```

## Verify

```bash
curl -H 'Host: mpit.localhost' http://127.0.0.1:9797/api/method/ping
docker compose exec frappe bench --site "$SITE_NAME" execute master_plan_it.devtools.verify.run
docker compose exec frappe bench --site "$SITE_NAME" run-tests --app master_plan_it
docker compose --profile test run --rm cypress
```

Expected:

```text
{"message":"pong"}
{"ok":["all_required_entities_present"], ...}
Frappe tests: OK
Cypress: 13 passing
```

## Commands

```bash
docker compose ps -a
docker compose logs -f frappe
docker compose exec frappe bash
docker compose exec frappe bench --site "$SITE_NAME" migrate
docker compose exec frappe bench --site "$SITE_NAME" clear-cache
```

## Reset

Deletes database, site files, bench, logs, and Redis data:

```bash
docker compose down -v --remove-orphans
rm -rf ./data
docker compose up -d
```

## Notes

- `setup` runs `bench init --skip-redis-config-generation --frappe-branch version-16`.
- `ALLOW_TESTS=1` enables Frappe test execution on the development site during setup.
- `CYPRESS_FRAPPE_USER` / `CYPRESS_FRAPPE_PASSWORD` define a dedicated test user that setup
  creates or updates, so Cypress does not depend on the current Administrator password.
- Redis is external; local Redis lines are removed from the generated Procfile.
- `web`, `socketio`, `watch`, `schedule`, and `worker` stay in the Procfile.
- Runtime uses `bench start --no-dev` so browsers connect to Socket.IO through
  the public origin instead of the container-only port 9000.

## Nginx Proxy Manager

For an HTTPS proxy host, forward normal traffic to `frappe:8000`, enable WebSocket
support, and add this Advanced configuration so Frappe realtime stays on the
same public origin:

```nginx
location /socket.io/ {
    proxy_pass http://frappe:9000/socket.io/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 120s;
}
```

Keep `DEVELOPER_MODE=0` for the proxied site. Otherwise Frappe intentionally
builds a browser URL with the internal Socket.IO port (`:9000`), which must not
be exposed publicly.

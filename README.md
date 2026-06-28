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
docker compose --profile test run --rm cypress
```

Expected:

```text
{"message":"pong"}
{"ok":["all_required_entities_present"], ...}
Cypress: 12 passing
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

Deletes database, site files, bench, logs, Redis data, and Cypress artifacts:

```bash
docker compose down -v --remove-orphans
rm -rf ./data ./cypress-artifacts
docker compose up -d
```

## Notes

- `setup` runs `bench init --skip-redis-config-generation --frappe-branch version-16`.
- Redis is external; local Redis lines are removed from the generated Procfile.
- `web`, `socketio`, `watch`, `schedule`, and `worker` stay in the Procfile.
- Cypress artifacts are written to `./cypress-artifacts`.

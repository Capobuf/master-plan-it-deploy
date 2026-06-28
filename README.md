# master-plan-it-deploy

Development-only Docker Compose setup for the Master Plan IT Frappe Framework v16 app.

There is no production compose file in this repository. The stack uses the official
`frappe/bench:v5.31.0` development image, initializes a Frappe Framework v16 bench, bind-mounts
the app repository for live development, and runs Frappe with `bench start`.

## Repository Layout

Keep these repositories as siblings:

```text
master-plan-it-deploy/
Master-Plan-IT/
```

If your local app repository has another directory name, set `APP_PATH` in `.env`.

## First Run

```bash
cp .env.example .env
# Review variables in .env.
docker compose up -d
```

Open:

```text
http://mpit.localhost:9797
```

If your OS or browser does not resolve `*.localhost`, add a hosts entry or change
`SITE_NAME` to a resolvable local name.

Login:

- User: `Administrator`
- Password: value of `FRAPPE_PASSWORD`

## Services

- `db`: MariaDB.
- `redis`: single Redis instance for cache, queue, and socket.io.
- `setup`: one-shot bench initialization, site bootstrap and migration container.
- `frappe`: Frappe development server using `bench start`.
- `cypress`: profile-only UI test runner.

ERPNext is not installed because the app has no ERPNext runtime dependency. No demo data is
created. Cypress tests create and delete their own test data.

## Live Development

`APP_PATH` is mounted into the Frappe bench at:

```text
/home/frappe/frappe-bench/apps/master_plan_it
```

Python and app file changes are visible inside the container. Schema and DocType changes
still require migration, and cache-sensitive changes may require clearing cache.

## Useful Commands

```bash
docker compose logs -f frappe
docker compose exec frappe bash
docker compose exec frappe bench --site "$SITE_NAME" migrate
docker compose exec frappe bench --site "$SITE_NAME" clear-cache
docker compose exec frappe bench --site "$SITE_NAME" execute master_plan_it.devtools.verify.run
docker compose --profile test run --rm cypress
```

## Destructive Reset

This deletes all local development data and Cypress artifacts. It is not part of the
normal workflow.

```bash
docker compose down
rm -rf ./data ./cypress-artifacts
docker compose up -d
```

More details are in [docs/docker-dev.md](docs/docker-dev.md).

# Docker Development

This repository is a development-only Docker Compose environment for the Master Plan IT
Frappe Framework app. There is no production compose file, no custom production image, and
no demo data bootstrap.

## Repository Layout

Keep the deploy repository and app repository as siblings:

```text
master-plan-it-deploy/
Master-Plan-IT/
```

This workspace may use `master_plan_it/` as the app directory name. If so, set `APP_PATH`
in `.env` to that path.

## First Run

```bash
cp .env.example .env
# Review .env values.
docker compose up -d
```

By default the site is available at:

```text
http://mpit.localhost:9797
```

Most modern systems resolve `*.localhost` automatically. If your browser or OS does not,
add a local hosts entry or change `SITE_NAME` to a host name your machine resolves.

Login with user `Administrator` and the password from `FRAPPE_PASSWORD`.

## Container Model

The runtime stack is intentionally small:

- `db`: MariaDB 11.8 data store.
- `redis`: one Redis instance shared by cache, queue, and socket.io.
- `frappe`: Frappe development process runner using `bench start`.

The one-shot `setup` service initializes a Frappe Framework v16 bench with
`bench init --skip-redis-config-generation`, creates or updates the site, installs
`master_plan_it`, runs migrations, clears cache, and exits. The `cypress` service is only
started through the `test` profile.

ERPNext is not installed because the app has no ERPNext runtime dependency.

## Live Code

`APP_PATH` is bind-mounted into the container and linked into the bench at:

```text
/home/frappe/frappe-bench/apps/master_plan_it
```

Python and app file changes are visible inside the container immediately. Schema,
DocType, fixture, and patch changes still require:

```bash
docker compose exec frappe bench --site "$SITE_NAME" migrate
```

Cache-sensitive changes may also require:

```bash
docker compose exec frappe bench --site "$SITE_NAME" clear-cache
```

## Useful Commands

```bash
docker compose logs -f frappe
docker compose exec frappe bash
docker compose exec frappe bench --site "$SITE_NAME" migrate
docker compose exec frappe bench --site "$SITE_NAME" clear-cache
docker compose exec frappe bench --site "$SITE_NAME" execute master_plan_it.devtools.verify.run
docker compose --profile test run --rm cypress
```

## Reset

The following command deletes the local development database, site files, logs, and Redis data.
Use it only when you intentionally want a fresh local environment:

```bash
docker compose down -v --remove-orphans
rm -rf ./data
docker compose up -d
```

## Test Data

No demo Vendor, Contract, Expense, Project, or extra Cost Center records are created by
the Docker setup. Cypress tests create the records they need and delete them after the
test run.

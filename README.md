# master-plan-it-deploy

Docker Compose deployment for [Master Plan IT](https://github.com/Capobuf/master-plan-it) — a Frappe v16 app.

## Files

| File | Purpose |
|------|---------|
| `compose.prod.yml` | Production — uses pre-built image; no source mounts |
| `compose.dev.yml` | Development — bind-mounts app repo for live editing |
| `Dockerfile.frappe` | Builds custom image with the app baked in |
| `apps.json` | App list for build-time installation |
| `prod.env.example` | Production env template (copy → `prod.env`, never commit) |
| `config/prod-entrypoint.sh` | Production container entrypoint |
| `config/prod.Procfile` | Production process list |

## Production deploy

**Prerequisites:** pre-built image pushed to registry (`CUSTOM_IMAGE:CUSTOM_TAG`).

```bash
# 1. Clone this repo on the server
git clone https://github.com/Capobuf/master-plan-it-deploy.git
cd master-plan-it-deploy

# 2. Configure environment
cp prod.env.example prod.env
# Edit prod.env: set CUSTOM_IMAGE, CUSTOM_TAG, DB_ROOT_PASSWORD

# 3. Start (first run creates volumes)
docker compose -f compose.prod.yml --env-file prod.env up -d

# 4. Create a site (first run only)
docker compose -f compose.prod.yml exec backend \
  bench new-site <site.domain> \
  --no-mariadb-socket \
  --mariadb-root-password "$DB_ROOT_PASSWORD" \
  --admin-password "<admin-password>"
docker compose -f compose.prod.yml exec backend \
  bench --site <site.domain> install-app master_plan_it
docker compose -f compose.prod.yml exec backend \
  bench --site <site.domain> migrate
```

## Upgrade

```bash
# Pull new image, recreate containers, migrate
docker compose -f compose.prod.yml --env-file prod.env pull
docker compose -f compose.prod.yml --env-file prod.env up -d --force-recreate
docker compose -f compose.prod.yml exec backend bench --site <site.domain> migrate
```

## Build custom image

```bash
# Build from app repo root (apps.json is encoded at build time)
APPS_JSON_BASE64=$(base64 -w 0 apps.json)
docker build \
  --build-arg APPS_JSON_BASE64="$APPS_JSON_BASE64" \
  -f Dockerfile.frappe \
  -t ghcr.io/yourorg/mpit-frappe:<tag> .
docker push ghcr.io/yourorg/mpit-frappe:<tag>
```

## Development

```bash
# App repo must be a sibling directory: ../master_plan_it/
docker compose -f compose.dev.yml up -d

# Create dev site
docker compose -f compose.dev.yml exec frappe \
  bench new-site <site.local> \
  --no-mariadb-socket \
  --mariadb-root-password "${DB_ROOT_PASSWORD}" \
  --admin-password "admin"

# Full reset
docker compose -f compose.dev.yml down
rm -rf data/db data/sites
mkdir -p data/sites && chown -R 1000:1000 data/sites
docker compose -f compose.dev.yml up -d
```

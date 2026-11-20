#!/usr/bin/env bash
#
# setup-shopware-instance.sh
# ---------------------------------------------------------------------------
# Spin up an additional Shopware dev instance that runs *alongside* the others,
# reachable at http://<name>.orb.local via OrbStack, with a collision-free
# host portmap so several instances can be up at the same time.
#
# The OrbStack domain routes straight to the web container's internal port 8000
# regardless of published host ports, so the domain never collides. Only the
# published host ports (for direct localhost:PORT access) must be unique across
# instances — this script offsets them by `index * 100`.
#
#   index 0 -> primary defaults   (8000 / 5173 / 5175 / 9998 / 9999, db 3306, ...)
#   index 1 -> 8100 / 5273 / 5275 / 10098 / 10099, db 3406, adminer 9180, mail 8125
#   index 2 -> 8200 / 5373 / 5375 / 10198 / 10199, db 3506, adminer 9280, mail 8225
#
# Note: index 0 is the primary and is NOT generated here (it keeps the default
# portmap from compose.yaml). Pass index >= 1 for additional instances.
#
# Requirements: OrbStack (or Docker Desktop), git, and a source Shopware clone
# that uses the shopware docker-dev compose stack (compose.yaml at its root).
#
# Usage:
#   setup-shopware-instance.sh --name third --index 2 [options]
#
# Options:
#   --name NAME       Instance name -> NAME.orb.local          (required)
#   --index N         Port-offset index, N >= 1                      (required)
#   --dir DIR         Target clone directory
#                       (default: <parent-of-source>/shopware-NAME)
#   --source SRC      Local path or git URL to clone from
#                       (default: $SHOPWARE_HOME_REPOS/shopware, ~/Documents/shopware)
#   --branch BRANCH   Branch to check out            (default: trunk)
#   --no-install      Skip the install (just clone + config + up)
#   --force           Continue even if computed host ports look occupied
#   -h, --help        Show this help
# ---------------------------------------------------------------------------
set -euo pipefail

# ---- defaults --------------------------------------------------------------
NAME=""
INDEX=""
DIR=""
SOURCE="${SHOPWARE_HOME_REPOS:-$HOME/Documents}/shopware"
BRANCH="trunk"
DO_INSTALL=1
FORCE=0

PKG_CACHE_VOLUME="shopware-pkg-cache"
PKG_CACHE_MOUNT="/var/cache/shopware-pkg"
WEB_IMAGE="ghcr.io/shopware/docker-dev:php8.4-node24-caddy"

die() { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# The volume is external so every instance shares one; it starts root-owned,
# but the web container runs as www-data (1000).
ensure_pkg_cache_volume() {
    docker volume inspect "$PKG_CACHE_VOLUME" >/dev/null 2>&1 && return 0
    info "creating shared package cache volume ${PKG_CACHE_VOLUME}"
    docker volume create "$PKG_CACHE_VOLUME" >/dev/null
    docker run --rm -u root --entrypoint chown -v "${PKG_CACHE_VOLUME}:/c" "$WEB_IMAGE" 1000:1000 /c
}

# ---- args ------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)      NAME="${2:-}"; shift 2 ;;
        --index)     INDEX="${2:-}"; shift 2 ;;
        --dir)       DIR="${2:-}"; shift 2 ;;
        --source)    SOURCE="${2:-}"; shift 2 ;;
        --branch)    BRANCH="${2:-}"; shift 2 ;;
        --no-install) DO_INSTALL=0; shift ;;
        --force)     FORCE=1; shift ;;
        -h|--help)   sed -n '2,55p' "$0"; exit 0 ;;
        *)           die "unknown argument: $1 (use --help)" ;;
    esac
done

[[ -n "$NAME" ]] || die "--name is required"
[[ "$NAME" =~ ^[a-z0-9-]+$ ]] || die "--name must be lowercase [a-z0-9-]"
[[ -n "$INDEX" ]] || die "--index is required"
[[ "$INDEX" =~ ^[0-9]+$ ]] || die "--index must be a number"
[[ "$INDEX" -ge 1 ]] || die "--index must be >= 1 (index 0 is the primary)"

command -v git >/dev/null || die "git not found"
command -v docker >/dev/null || die "docker not found"

DOMAIN="${NAME}.orb.local"
if [[ -z "$DIR" ]]; then
    DIR="$(dirname "$SOURCE")/shopware-${NAME}"
fi

# ---- port map --------------------------------------------------------------
OFFSET=$(( INDEX * 100 ))
APP_PORT=$(( 8000 + OFFSET ))
VITE_ADMIN=$(( 5173 + OFFSET ))
VITE_SF=$(( 5175 + OFFSET ))
DEBUG1=$(( 9998 + OFFSET ))
DEBUG2=$(( 9999 + OFFSET ))
DB_PORT=$(( 3306 + OFFSET ))
ADMINER_PORT=$(( 9080 + OFFSET ))
MAILER_PORT=$(( 8025 + OFFSET ))

info "instance : ${NAME}  ->  http://${DOMAIN}"
info "directory: ${DIR}"
info "source   : ${SOURCE}  (branch ${BRANCH})"
info "ports    : app=${APP_PORT} viteAdmin=${VITE_ADMIN} viteSf=${VITE_SF} debug=${DEBUG1},${DEBUG2} db=${DB_PORT} adminer=${ADMINER_PORT} mail=${MAILER_PORT}"

# ---- preflight: are the host ports free? -----------------------------------
port_busy() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }
CONFLICTS=""
for p in "$APP_PORT" "$VITE_ADMIN" "$VITE_SF" "$DEBUG1" "$DEBUG2" "$DB_PORT" "$ADMINER_PORT" "$MAILER_PORT"; do
    if port_busy "$p"; then CONFLICTS+=" $p"; fi
done
if [[ -n "$CONFLICTS" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
        info "WARNING: host ports already in use:${CONFLICTS} (continuing due to --force)"
    else
        die "host ports already in use:${CONFLICTS} — pick another --index or pass --force"
    fi
fi

# ---- clone -----------------------------------------------------------------
if [[ -d "$DIR/.git" ]]; then
    info "clone already exists at ${DIR}, skipping git clone"
else
    [[ -e "$DIR" ]] && die "${DIR} exists but is not a git repo"
    info "cloning ${SOURCE} -> ${DIR}"
    git clone "$SOURCE" "$DIR"
fi
info "checking out ${BRANCH}"
git -C "$DIR" checkout "$BRANCH"

# ---- compose.override.yaml -------------------------------------------------
info "writing compose.override.yaml"
cat > "$DIR/compose.override.yaml" <<YAML
services:
    web:
        environment:
            APP_URL: http://${DOMAIN}
            # 5175 (storefront vite) is published on the host as ${VITE_SF}.
            STOREFRONT_VITE_ORIGIN: http://localhost:${VITE_SF}
            COMPOSER_CACHE_DIR: ${PKG_CACHE_MOUNT}/composer
            npm_config_cache: ${PKG_CACHE_MOUNT}/npm
        # Download cache shared by every instance and kept across container
        # recreation; without it each container starts with an empty cache.
        volumes:
            - ${PKG_CACHE_VOLUME}:${PKG_CACHE_MOUNT}
        # Full portmap, offset by index ${INDEX} so this stack runs alongside
        # the others. The domain below routes to the container's internal
        # port 8000 and is unaffected by these host ports.
        ports: !override
            - ${APP_PORT}:8000
            - ${VITE_ADMIN}:5173
            - ${VITE_SF}:5175
            - ${DEBUG1}:9998
            - ${DEBUG2}:9999
        labels:
            - dev.orbstack.domains=${DOMAIN}
            - dev.orbstack.http-port=8000

    database:
        ports: !override
            - ${DB_PORT}:3306

    adminer:
        ports: !override
            - ${ADMINER_PORT}:8080

    mailer:
        ports: !override
            - ${MAILER_PORT}:8025

volumes:
    ${PKG_CACHE_VOLUME}:
        external: true
YAML

# ---- bring up + install ----------------------------------------------------
cd "$DIR"
ensure_pkg_cache_volume
info "docker compose up -d"
docker compose up -d --remove-orphans

if [[ "$DO_INSTALL" -eq 1 ]]; then
    if [[ -f "$DIR/vendor/autoload.php" ]]; then
        info "vendor/ already present — skipping install (delete it or use --no-install to control this)"
    else
        info "running shopware-instance reset: composer setup, with vendor/ and node_modules from ~/.shopware-nm"
        "$(cd -P "$(dirname "$0")" && pwd)/shopware-instance" reset --no-demodata
    fi
fi

# ---- point the storefront sales-channel domain at ${DOMAIN} ----------------
info "updating sales_channel_domain.url -> http://${DOMAIN}"
docker compose exec -T database \
    mariadb -uroot -proot shopware \
    -e "UPDATE sales_channel_domain SET url='http://${DOMAIN}' WHERE url LIKE 'http%';" \
    || info "WARNING: could not update sales_channel_domain (is the DB installed yet?)"

# ---- summary ---------------------------------------------------------------
cat <<DONE

Done. Instance '${NAME}' is up.

  Storefront : http://${DOMAIN}/
  Admin      : http://${DOMAIN}/admin        (login admin / shopware)
  Direct     : http://localhost:${APP_PORT}/  (admin at /admin)
  Vite admin : localhost:${VITE_ADMIN}         (only while 'composer watch:admin' runs)
  Adminer    : http://localhost:${ADMINER_PORT}
  Mailpit    : http://localhost:${MAILER_PORT}
  DB         : localhost:${DB_PORT}  (root / root)

Compose project: $(basename "$DIR")  (containers $(basename "$DIR")-web-1, ...)
DONE

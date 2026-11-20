#!/usr/bin/env bash
#
# attach.sh — make a git worktree runnable against an existing Shopware instance.
#
# A worktree is a bare checkout: no vendor/, no node_modules, no var/, no .env.
# This script supplies each of those from the instance the worktree belongs to,
# so the worktree can run jest, eslint, phpunit and its own vite dev server
# while sharing the instance's backend (PHP-FPM + MariaDB + OpenSearch).
#
# Only deterministic work happens here. Anything that can fail in an interesting
# way (npm ci, composer install, a broken backend) is printed as a TODO for the
# agent to run and troubleshoot itself.
#
# Run from the worktree, on the host. Idempotent.
#   --subject "<text>"   one line naming what this worktree is for; the devboard
#                        dashboard (devboard.py) shows it next to the dev server
#   --skip-plugin <dir>  do not link this instance plugin into the worktree;
#                        repeatable and remembered for later attaches
#
# The backend is always the worktree's own instance (the repo it was created
# from). Choose the backend when you create the worktree:
#   git -C <home repo>/repositories/shopware/shopware-2 worktree add .claude/worktrees/<name>
# A worktree under the instance root is inside the container's
# '.:/var/www/html' mount already. One elsewhere (e.g. a harness's own worktree folder) is
# reached through mirror mounts at the identical host path; attach.sh prints the
# one-time compose.override.yaml lines when the container lacks them.
set -euo pipefail

ADMIN_REL="src/Administration/Resources/app/administration"
DEVBOARD="$(cd "$(dirname "$0")" && pwd)/devboard.py"
# Generic helpers of the worktree-attach skill, from the gweiermann/skills submodule.
GENERIC="$(cd -P "$(dirname "$0")/../../general/skills/worktree-attach/scripts" && pwd)"
FORWARD="$GENERIC/forward.mjs"
TODO=()

# Records a step the agent must run itself, printed as a numbered TODO at the end.
todo() { TODO+=("$1"); }

say() { printf '%s\n' "$*"; }
die() { printf 'attach: %s\n' "$*" >&2; exit 1; }

# Copy-on-write clone of a whole directory tree via APFS clonefile(2): one
# syscall, seconds for a 1 GB node_modules, and no extra disk. Falls back to
# `cp -Rc` (same sharing, per-file, minutes) off APFS.
clone_tree() {
    python3 -c '
import ctypes, ctypes.util, sys
libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
libc.clonefile.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
sys.exit(0 if libc.clonefile(sys.argv[1].encode(), sys.argv[2].encode(), 0) == 0 else 1)
' "$1" "$2" 2>/dev/null || cp -Rc "$1" "$2"
}

# --- resolve worktree, owning instance, and the path both share inside the container

WT=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
INSTANCE=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")

[ "$WT" = "$INSTANCE" ] && die "this is the instance checkout itself, not a worktree — nothing to attach"

SUBJECT=""
SKIP_ADD=()
while [ $# -gt 0 ]; do
    case "$1" in
        --subject) [ -n "${2:-}" ] || die "--subject needs a text"; SUBJECT=$2; shift 2 ;;
        --skip-plugin) [ -n "${2:-}" ] || die "--skip-plugin needs a plugin directory name"; SKIP_ADD+=("$2"); shift 2 ;;
        --backend) die "the backend is fixed to $INSTANCE, the repo this worktree belongs to.
   To use another instance's stack, create the worktree under it:
   git -C <home repo>/repositories/shopware/shopware-<n> worktree add .claude/worktrees/$(basename "$WT")" ;;
        *) die "unknown argument: $1" ;;
    esac
done

# Plugins the worktree must not load, e.g. an instance plugin whose config this
# branch's kernel rejects. Kept in the worktree's git dir like the devboard subject.
SKIP_FILE="$(git rev-parse --path-format=absolute --git-dir)/attach-skip-plugins"
for name in ${SKIP_ADD[@]+"${SKIP_ADD[@]}"}; do
    grep -qxF "$name" "$SKIP_FILE" 2>/dev/null || echo "$name" >> "$SKIP_FILE"
done
is_skipped() { grep -qxF "$1" "$SKIP_FILE" 2>/dev/null; }

BACKEND_DIR="$INSTANCE"

case "$WT" in
    "$INSTANCE"/*)
        WT_REL=${WT#"$INSTANCE"/}             # .claude/worktrees/<name>
        WT_CTR="/var/www/html/$WT_REL"        # same path inside the container
        INSTANCE_CTR="/var/www/html"
        UPS=$(printf '../%.0s' $(seq 1 "$(tr -cd / <<<"$WT_REL" | wc -c | tr -d ' ')") )
        PLUGIN_SRC="../../${UPS}../custom/plugins"   # worktree plugin dir -> instance plugin dir
        ;;
    *)
        # Mirror mounts: the worktree and the instance sit at their host paths in
        # the container too, so one absolute plugin symlink resolves on both sides.
        WT_CTR="$WT"
        INSTANCE_CTR="$INSTANCE"
        PLUGIN_SRC="$INSTANCE/custom/plugins"
        ;;
esac

# Runs a command inside the backend's web container, from the worktree root.
in_container() { (cd "$BACKEND_DIR" && docker compose exec -T web bash -c "cd $WT_CTR && $1"); }

# The mounts an outside worktree needs: its parent directory, so every sibling
# worktree is covered at once, and the instance root for the plugin symlinks.
mirror_mounts_todo() {
    todo "The web container cannot see $WT_CTR. Add mirror mounts to the web service in
     $BACKEND_DIR/compose.override.yaml:
         volumes:
             - $(dirname "$WT"):$(dirname "$WT")
             - .:$INSTANCE
   Then recreate the container (stops every dev server running in it):
     cd $BACKEND_DIR && docker compose up -d web
   and re-run attach.sh."
}

CONTAINER_OK=0
if [ -z "$(docker compose --project-directory "$BACKEND_DIR" ps -q web 2>/dev/null)" ]; then
    todo "Backend is down. Start it: cd $BACKEND_DIR && docker compose up -d web database
   Then re-run attach.sh. If it starts but /admin 500s, follow the repair ladder in the shopware-local-dev skill."
elif ! in_container "test -f composer.json && test -f $INSTANCE_CTR/composer.json" 2>/dev/null; then
    mirror_mounts_todo
else
    CONTAINER_OK=1
fi

[ -n "$SUBJECT" ] && (cd "$WT" && "$DEVBOARD" subject "$SUBJECT" >/dev/null)
CURRENT_SUBJECT=$(cd "$WT" && "$DEVBOARD" subject)
[ "$CURRENT_SUBJECT" = "(no subject)" ] \
    && todo "Name what this worktree is for, so the devboard dashboard can tell it apart from the others:
     attach.sh --subject '<issue/PR number + one-line goal>'"

say "worktree : $WT"
say "instance : $INSTANCE  (also the backend)"
say "subject  : $CURRENT_SUBJECT"
say ""

# Prints the collected TODOs and exits, or returns when there are none.
report_todos() {
    say ""
    [ ${#TODO[@]} -gt 0 ] || return 0
    say "NOT READY — ${#TODO[@]} step(s) for you to run:"
    i=1; for t in "${TODO[@]}"; do say ""; say "$i. $t"; i=$((i+1)); done
    exit 1
}

# Every step below runs at least one command inside the container.
[ "$CONTAINER_OK" = 1 ] || report_todos

# --- node_modules: materialised from a store keyed by package-lock.json
#
# A symlink would be cheaper, but vite then serves dependency assets through
# /@fs/<realpath outside the worktree> and its own fs.allow rejects them with a
# 403 (fonts, svgs). A cloned real directory sidesteps that for free.

lock_hash() { shasum -a 256 "$1/$ADMIN_REL/package-lock.json" | cut -c1-12; }

# npm records what it actually installed in node_modules/.package-lock.json. A
# matching lockfile hash alone also accepts a tree installed from an older lock,
# which then poisons the store for every worktree cloned from it.
matches_lock() { "$GENERIC/npm-tree-matches-lock" "$1" "$WT/$ADMIN_REL/package-lock.json" 2>/dev/null; }

WT_LOCK=$(lock_hash "$WT")
INSTANCE_LOCK=$(lock_hash "$INSTANCE")
NM="$WT/$ADMIN_REL/node_modules"
STORE="$HOME/.shopware-nm/$WT_LOCK/node_modules"

if [ -d "$NM/.bin" ] && [ ! -L "$NM" ] && matches_lock "$NM"; then
    say "node_modules  present, matches lockfile $WT_LOCK"
else
    [ -e "$NM" ] && say "node_modules  present but does not match lockfile $WT_LOCK, replacing it"
    rm -rf "$NM"
    if [ -d "$STORE" ] && ! matches_lock "$STORE"; then
        rm -rf "$STORE"
        say "node_modules  stale store entry $WT_LOCK discarded"
    fi
    if [ ! -d "$STORE" ] && matches_lock "$INSTANCE/$ADMIN_REL/node_modules"; then
        mkdir -p "$(dirname "$STORE")"
        clone_tree "$INSTANCE/$ADMIN_REL/node_modules" "$STORE"
        say "node_modules  store seeded from the instance ($WT_LOCK)"
    fi
    if [ -d "$STORE" ]; then
        clone_tree "$STORE" "$NM"
        say "node_modules  cloned from store $WT_LOCK"
    else
        mkdir -p "$(dirname "$STORE")"
        todo "No node_modules matching lockfile $WT_LOCK, neither in the store nor in the instance (lockfile $INSTANCE_LOCK). Install once, then park it in the store:
     cd $BACKEND_DIR && docker compose exec -T web bash -c 'cd $WT_CTR/$ADMIN_REL && npm ci'
     mv $NM $STORE
   Then re-run attach.sh. Every worktree on this lockfile clones from it in seconds."
    fi
fi

# --- vendor: cheap APFS clone, then re-dumped so the autoloader points at THIS checkout

if [ -f "$WT/vendor/autoload.php" ]; then
    say "vendor        present"
elif cmp -s "$WT/composer.lock" "$INSTANCE/composer.lock"; then
    clone_tree "$INSTANCE/vendor" "$WT/vendor"
    in_container 'composer dump-autoload -q'
    say "vendor        cloned + autoload re-dumped"
else
    todo "composer.lock differs from the instance, so its vendor/ cannot be cloned. Install in the worktree:
     cd $BACKEND_DIR && docker compose exec -T web bash -c 'cd $WT_CTR && composer install'"
fi

# --- custom/: gitignored, so plugins active in the shared DB are absent from the worktree

# custom/plugins/.gitkeep is tracked, so the directory exists but is always empty
# in a worktree; each plugin the shared DB has installed is symlinked in.
if [ -d "$INSTANCE/custom/plugins" ]; then
    linked=0
    for p in "$INSTANCE"/custom/plugins/*/; do
        [ -d "$p" ] || continue
        name=$(basename "$p")
        if is_skipped "$name"; then
            [ -L "$WT/custom/plugins/$name" ] && rm "$WT/custom/plugins/$name"
            say "custom/plugins $name skipped (--skip-plugin)"
            continue
        fi
        [ -e "$WT/custom/plugins/$name" ] && continue
        mkdir -p "$WT/custom/plugins"
        ln -sfn "$PLUGIN_SRC/$name" "$WT/custom/plugins/$name"
        linked=$((linked+1))
    done
    [ "$linked" -gt 0 ] && say "custom/plugins $linked plugin(s) symlinked from the instance"
fi

# --- .env: PROJECT_ROOT must name THIS worktree, or vite reads the instance's var/ and custom/

[ -f "$WT/.env" ] || { cp "$INSTANCE/.env" "$WT/.env" 2>/dev/null && say ".env          copied"; }

# The backend's own URL, however that instance happens to declare it.
backend_app_url() {
    { grep -hs -e '^APP_URL=' -e 'APP_URL:' \
        "$BACKEND_DIR/compose.override.yaml" "$BACKEND_DIR/.env.local" "$BACKEND_DIR/compose.yaml" \
        || true; } | head -1 | sed -e 's/.*APP_URL[:=] *//' -e "s/['\"]//g"
}
APP_URL=$(backend_app_url)
APP_URL=${APP_URL:-http://localhost:8000}

# Port is derived from the worktree name so two worktrees never propose the same
# one; vite's own findAvailablePorts() still probes upward from here.
ADMIN_PORT=$(( 5300 + 10 * ( 0x$(basename "$WT" | shasum -a 256 | cut -c1-4) % 60 ) ))

{
    grep -v -e '^PROJECT_ROOT=' -e '^APP_URL=' -e '^ADMIN_PORT=' "$INSTANCE/.env.local" 2>/dev/null || true
    echo "PROJECT_ROOT=$WT_CTR"
    echo "APP_URL=$APP_URL"
    echo "ADMIN_PORT=$ADMIN_PORT"
} > "$WT/.env.local"
say ".env.local    PROJECT_ROOT=$WT_CTR  APP_URL=$APP_URL  ADMIN_PORT=$ADMIN_PORT"

# --- var/: generated, and vite refuses to start without it

if [ ! -f "$WT/var/plugins.json" ] || [ ! -f "$WT/var/config_js_features.json" ]; then
    if in_container 'bin/console bundle:dump -q && bin/console feature:dump -q' 2>/dev/null; then
        say "var/          bundle:dump + feature:dump"
    else
        todo "bundle:dump / feature:dump failed — they need a reachable DB and a working vendor/. Run them and read the error:
     cd $BACKEND_DIR && docker compose exec -T web bash -c 'cd $WT_CTR && bin/console bundle:dump && bin/console feature:dump'
   A config error from an instance plugin (its files are not on this branch's schema) means
   that plugin cannot boot here: re-run attach.sh --skip-plugin <dir name under custom/plugins>."
    fi
fi

# --- jest fixtures: generated, gitignored, and the suite dies without them

SCHEMA="test/_mocks_/entity-schema.json"
if [ ! -f "$WT/$ADMIN_REL/$SCHEMA" ]; then
    if [ -f "$INSTANCE/$ADMIN_REL/$SCHEMA" ]; then
        mkdir -p "$(dirname "$WT/$ADMIN_REL/$SCHEMA")"
        cp "$INSTANCE/$ADMIN_REL/$SCHEMA" "$WT/$ADMIN_REL/$SCHEMA"
        say "jest fixture  $SCHEMA"
    else
        todo "Missing jest fixture $SCHEMA and the instance has no copy. Generate it: composer framework:schema:dump"
    fi
fi

# Both are derived from the worktree's own sources, so an instance copy is stale
# whenever the branch adds, moves or removes components or entity types.
if in_container "cd $ADMIN_REL && npm run -s unit-setup >/dev/null && npm run -s convert-entity-schema >/dev/null" 2>/dev/null; then
    say "generated     component-imports.js + entity-schema-definition.d.ts"
else
    todo "Generating the jest component map or the entity types failed. Run them and read the error:
     cd $BACKEND_DIR && docker compose exec -T web bash -c 'cd $WT_CTR/$ADMIN_REL && npm run unit-setup && npm run convert-entity-schema'"
fi

# --- localhost forwarder: browser agents may only log in on localhost

# The OrbStack domain routes every container port, and unlike the container's
# own IP it is reachable from sandboxed browsers (Playwright MCP).
ADMIN_HOST=$(printf '%s' "$APP_URL" | sed -e 's|.*://||' -e 's|[/:].*||')

if pgrep -qf "forward.mjs $ADMIN_HOST $ADMIN_PORT\$"; then
    say "forwarder     localhost:$ADMIN_PORT -> $ADMIN_HOST:$ADMIN_PORT (already running)"
elif lsof -nP -iTCP:"$ADMIN_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    todo "localhost:$ADMIN_PORT is taken by something else, so the admin cannot be forwarded to localhost. Find it:
     lsof -nP -iTCP:$ADMIN_PORT -sTCP:LISTEN"
else
    nohup node "$FORWARD" "$ADMIN_HOST" "$ADMIN_PORT" > "${TMPDIR:-/tmp}/forward-$ADMIN_PORT.log" 2>&1 &
    say "forwarder     localhost:$ADMIN_PORT -> $ADMIN_HOST:$ADMIN_PORT (started)"
fi

# --- report

report_todos

cat <<EOF
READY. Run everything from $BACKEND_DIR, targeting the worktree:

  jest      docker compose exec -T web bash -c 'cd $WT_CTR/$ADMIN_REL && ./node_modules/.bin/jest --config jest.config.js --collectCoverage=false --runTestsByPath <paths>'
  eslint    docker compose exec -T web bash -c 'cd $WT_CTR && composer eslint:admin'
  phpunit   docker compose exec -T web bash -c 'cd $WT_CTR && ./vendor/bin/phpunit --configuration phpunit.xml.dist <path>'
  dev srv   docker compose exec -T -d web bash -c 'cd $WT_CTR && composer npm:admin run dev > /tmp/vite-$(basename "$WT").log 2>&1'
  admin     http://localhost:$ADMIN_PORT/   (forwarded; log in here, not on $ADMIN_HOST)
  vite log  docker compose exec -T web tail -40 /tmp/vite-$(basename "$WT").log
  board     $DEVBOARD list   (or: serve --open)
EOF

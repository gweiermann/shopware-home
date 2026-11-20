#!/usr/bin/env bash
#
# link-local.sh — serve a local upstream checkout to a Shopware worktree, so a
# fix can be written and proven in the repository that owns the code.
#
#   meteor -> ~/Documents/meteor/packages/component-library
#             (@shopware-ag/meteor-component-library, used by the Administration)
#   ats    -> ~/Documents/acceptance-test-suite
#             (@shopware-ag/acceptance-test-suite, used by tests/acceptance)
#
# Those are only the defaults. The fix often sits on a branch in a worktree of
# one of them, so --from takes any checkout of the same repo and --list shows
# which ones exist. Whichever is used, its path is printed: linking the wrong
# checkout looks exactly like linking the right one.
#
# It replaces the installed package's dist/ with a clone of the local build.
# Copy-on-write, so the shared ~/.shopware-nm store and every other worktree
# keep the published build.
#
# Run from the worktree, on the host, after attach.sh reports READY.
#
# Usage: link-local.sh meteor|ats [--from <path|worktree>] [--restore]
#        link-local.sh meteor|ats --list
#   --from     the checkout to link, as a repo root, a package directory, or the
#              name of a worktree under <repo>/.claude/worktrees/
#   --restore  put the published build back
#   --list     show every checkout of the upstream repo, then exit
set -euo pipefail

say() { printf '%s\n' "$*"; }
die() { printf 'link-local: %s\n' "$*" >&2; exit 1; }

# See attach.sh — one clonefile(2) per tree, seconds and no extra disk.
clone_tree() {
    python3 -c '
import ctypes, ctypes.util, sys
libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
libc.clonefile.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
sys.exit(0 if libc.clonefile(sys.argv[1].encode(), sys.argv[2].encode(), 0) == 0 else 1)
' "$1" "$2" 2>/dev/null || cp -Rc "$1" "$2"
}

pkg_field() { node -p "require('$1/package.json').$2" 2>/dev/null || true; }

ADMIN_REL="src/Administration/Resources/app/administration"

TARGET=${1:-}
[ $# -gt 0 ] && shift
RESTORE=""
LIST=""
FROM=""
while [ $# -gt 0 ]; do
    case "$1" in
        --restore) RESTORE=1 ;;
        --list) LIST=1 ;;
        --from|--src) [ $# -gt 1 ] || die "--from needs a path or worktree name"; shift; FROM=$1 ;;
        --from=*) FROM=${1#*=} ;;
        --src=*) FROM=${1#*=} ;;
        *) die "unknown argument: $1
   usage: $(basename "$0") meteor|ats [--from <path|worktree>] [--restore]" ;;
    esac
    shift
done

case "$TARGET" in
    meteor)
        ROOT="${SHOPWARE_HOME_REPOS:-$HOME/Documents}/meteor"
        SRC_REL="packages/component-library"
        PKG="@shopware-ag/meteor-component-library"
        NM_REL="$ADMIN_REL"
        BUILD_HINT="pnpm build-only"
        ;;
    ats)
        ROOT="${SHOPWARE_HOME_REPOS:-$HOME/Documents}/acceptance-test-suite"
        SRC_REL="."
        PKG="@shopware-ag/acceptance-test-suite"
        NM_REL="tests/acceptance"
        BUILD_HINT="npm run build"
        ;;
    *) die "usage: $(basename "$0") meteor|ats [--from <path|worktree>] [--restore]" ;;
esac

# Every checkout of the upstream repo: the main one plus its worktrees.
checkouts() {
    git -C "$ROOT" worktree list --porcelain 2>/dev/null | awk '/^worktree /{ $1=""; sub(/^ /, ""); print }'
}

describe_checkout() {
    local root=$1 pkgdir version branch dirty="" build="no build"
    pkgdir="$root/$SRC_REL"
    version=$(pkg_field "$pkgdir" version)
    branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
    git -C "$root" status --porcelain 2>/dev/null | grep -q . && dirty=", uncommitted changes"
    [ -d "$pkgdir/dist" ] && build="built $(date -r "$pkgdir/dist" '+%Y-%m-%d %H:%M' 2>/dev/null)"
    printf '  %s\n      %s %s  (%s%s)\n' "$root" "${version:-?}" "$build" "$branch" "$dirty"
}

if [ -n "$LIST" ]; then
    say "checkouts of $PKG:"
    while read -r root; do [ -n "$root" ] && describe_checkout "$root"; done <<< "$(checkouts)"
    say ""
    say "Link one with: $(basename "$0") $TARGET --from <path>"
    exit 0
fi

# --from takes a repo root, a package directory, or a worktree name. Resolve it
# to the package directory, and only accept one that really holds this package.
resolve_src() {
    local given=$1 candidate
    for candidate in "$given" "$given/$SRC_REL" "$ROOT/.claude/worktrees/$given" \
                     "$ROOT/.claude/worktrees/$given/$SRC_REL"; do
        [ -d "$candidate" ] || continue
        if [ "$(pkg_field "$candidate" name)" = "$PKG" ]; then
            (cd "$candidate" && pwd -P)
            return 0
        fi
    done
    die "no $PKG checkout at $given.
   Pass a repo root, a package directory, or a worktree name under
   $ROOT/.claude/worktrees/. See: $(basename "$0") $TARGET --list"
}

if [ -n "$FROM" ]; then
    SRC=$(resolve_src "$FROM")
else
    SRC="$ROOT/$SRC_REL"
    [ -d "$SRC" ] || die "no local checkout at $SRC"
fi

SRC_ROOT=$(git -C "$SRC" rev-parse --show-toplevel 2>/dev/null || echo "$SRC")
BUILD_CMD="cd $SRC && $BUILD_HINT"

WT=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git repository"
INSTANCE=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
WT_CTR="/var/www/html/${WT#"$INSTANCE"/}"     # the worktree, as the container sees it

NM="$WT/$NM_REL/node_modules"
LOCK="$WT/$NM_REL/package-lock.json"
VITE_CACHE=""
[ "$TARGET" = meteor ] && VITE_CACHE="$NM/.vite"

# tests/acceptance/node_modules is gitignored, so a worktree never has one.
if [ ! -d "$NM" ]; then
    INSTANCE_NM=${NM/#$WT/$INSTANCE}
    if [ -d "$INSTANCE_NM" ] && cmp -s "$LOCK" "${LOCK/#$WT/$INSTANCE}"; then
        clone_tree "$INSTANCE_NM" "$NM"
        say "$(basename "$(dirname "$NM")")/node_modules cloned from the instance"
    else
        die "no $NM, and the instance's lockfile differs so it cannot be cloned.
   Install it, read any error, then re-run:
   cd $INSTANCE && docker compose exec -T web bash -c 'cd $WT_CTR/$NM_REL && npm ci'"
    fi
fi

DEST="$NM/$PKG"
[ -d "$DEST" ] || die "$PKG is not installed in $NM — run attach.sh first"

installed_version() { node -p "require('$DEST/package.json').version"; }

if [ -n "$RESTORE" ]; then
    STORE="$HOME/.shopware-nm/$(shasum -a 256 "$LOCK" | cut -c1-12)/node_modules/$PKG/dist"
    FROM_DIST="$STORE"
    [ -d "$FROM_DIST" ] || FROM_DIST="${NM/#$WT/$INSTANCE}/$PKG/dist"
    [ -d "$FROM_DIST" ] || die "no published build to restore from. Reinstall: rm -rf $NM and re-run attach.sh"
    rm -rf "$DEST/dist" && clone_tree "$FROM_DIST" "$DEST/dist"
    [ -n "$VITE_CACHE" ] && rm -rf "$VITE_CACHE"
    say "restored $PKG $(installed_version) from $FROM_DIST"
    exit 0
fi

LOCAL_VERSION=$(pkg_field "$SRC" version)
INSTALLED_VERSION=$(installed_version)

say "local    $PKG $LOCAL_VERSION"
say "         from $SRC  ($(git -C "$SRC" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')$(git -C "$SRC" status --porcelain | grep -q . && echo ', uncommitted changes'))"
say "replaces $PKG $INSTALLED_VERSION  in $NM"

# The branch carrying the fix is often not the one in the main checkout, and a
# link from the wrong checkout reads as a successful link.
if [ -z "$FROM" ]; then
    OTHERS=$(checkouts | grep -v "^$SRC_ROOT$" || true)
    if [ -n "$OTHERS" ]; then
        say ""
        say "Other checkouts of this repo, unused here (pass --from to link one):"
        while read -r root; do [ -n "$root" ] && describe_checkout "$root"; done <<< "$OTHERS"
    fi
fi

[ -d "$SRC/dist" ] || die "$SRC has no build output. Build it, read any error, then re-run:
   $BUILD_CMD"

if [ -d "$SRC/src" ] && [ -n "$(find "$SRC/src" -type f -newer "$SRC/dist" -print -quit 2>/dev/null)" ]; then
    say ""
    say "STALE BUILD. $SRC/src has files newer than its dist/, so the link would"
    say "carry an older build than the checkout. Rebuild first, then re-run:"
    say "   $BUILD_CMD"
fi

rm -rf "$DEST/dist"
clone_tree "$SRC/dist" "$DEST/dist"
[ -n "$VITE_CACHE" ] && rm -rf "$VITE_CACHE"

say ""
say "Linked. The store and every other worktree still hold the published build."

if [ "$LOCAL_VERSION" != "$INSTALLED_VERSION" ]; then
    say ""
    say "VERSION MISMATCH. The worktree's lockfile pins $INSTALLED_VERSION, your checkout is"
    say "$LOCAL_VERSION, so what you prove here is not what the pinned version does. Decide which"
    say "you mean before reading any result: check out the matching tag in $SRC, or"
    say "bump the pin in the worktree and treat that bump as part of the change."
    say ""
fi

case "$TARGET" in
    meteor) say "Restart the dev server (the prebundle cache is cleared), then reload the admin.
Rebuild in $SRC and re-run this after every upstream edit — vite does not watch dist/." ;;
    ats)    say "Re-run the acceptance test. Rebuild in $SRC and re-run this after every upstream edit." ;;
esac
say "Undo with: $(basename "$0") $TARGET --restore"

#!/usr/bin/env bash
#
# install.sh — link the home repo's skills and tools into place. Never overwrites.
#
#   bin/install.sh [--dry-run]
#
# Skills are linked into ~/.agents/skills (read by Codex and others) and from
# there into ~/.claude/skills. Tools in bin/ are linked into ~/bin.
# A target that exists and is not already this repo's link is left alone and
# reported as a conflict: migrating it is a decision (the setup-home skill).
set -euo pipefail

HOME_REPO="$(cd -P "$(dirname "$0")/.." && pwd)"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

AGENTS_SKILLS="$HOME/.agents/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"
BIN="$HOME/bin"

# worktree-attach is used by shopware-worktree-dev as a script library; linking
# it as a skill as well would make two skills compete for the same trigger.
SKIP_SKILLS=" worktree-attach "

# Skills that took over an older skill under another name. Both installed means
# two skills compete for the same trigger, so the new one waits for migration.
replaced_by() {
    case "$1" in
        babysit-pr | babysit-all-prs) echo pr-babysit ;;
        shopware-commercial-companion) echo commercial-downstream-pr ;;
    esac
}

linked=0 conflicts=()

# Links $2 -> $1 unless $2 already exists as something else.
link() {
    local src=$1 dst=$2
    if [ -L "$dst" ] && [ "$(cd -P "$dst" 2>/dev/null && pwd || readlink "$dst")" = "$(cd -P "$src" 2>/dev/null && pwd || echo "$src")" ]; then
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        conflicts+=("$dst  (wanted → $src)")
        return
    fi
    linked=$((linked + 1))
    if [ "$DRY" = 1 ]; then echo "would link $dst → $src"; else ln -s "$src" "$dst" && echo "linked $dst"; fi
}

[ -f "$HOME_REPO/general/skills/babysit-pr/SKILL.md" ] || {
    echo "general/ is empty: git -C $HOME_REPO submodule update --init" >&2
    exit 1
}

[ "$DRY" = 1 ] || mkdir -p "$AGENTS_SKILLS" "$CLAUDE_SKILLS" "$BIN"

for skill_md in "$HOME_REPO"/skills/*/SKILL.md "$HOME_REPO"/general/skills/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    dir=$(dirname "$skill_md")
    name=$(basename "$dir")
    case "$SKIP_SKILLS" in *" $name "*) continue ;; esac
    old=$(replaced_by "$name")
    if [ -n "$old" ] && { [ -e "$CLAUDE_SKILLS/$old" ] || [ -e "$AGENTS_SKILLS/$old" ]; }; then
        conflicts+=("$name  (replaces the installed $old)")
        continue
    fi
    link "$dir" "$AGENTS_SKILLS/$name"
    link "$AGENTS_SKILLS/$name" "$CLAUDE_SKILLS/$name"
done

for tool in shopware-instance setup-shopware-instance.sh; do
    link "$HOME_REPO/bin/$tool" "$BIN/$tool"
done

echo "$linked new link(s)."
if [ ${#conflicts[@]} -gt 0 ]; then
    echo "Left alone, already exist (migrate with the setup-home skill):"
    printf '  %s\n' "${conflicts[@]}"
fi

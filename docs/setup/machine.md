# Machine setup

What a Mac needs to run Shopware with agents the way this repo assumes.
The `setup-home` skill walks through it and adapts it; this is the reference.

## Tools

- [OrbStack](https://orbstack.dev) as the Docker runtime: it routes `<name>.orb.local` to containers without published ports.
- `git`, an authenticated [GitHub CLI](https://cli.github.com) (`gh auth login`), and [`gh stack`](https://github.com/github/gh-stack) for linked stacks.
- `python3` and `node` on the host for the scripts here; everything Shopware-related runs in the containers.
- A Playwright MCP server for browser work.

## Repos and instances

Clone what `AGENTS.md` lists into `repositories/` ([the layout](../../repositories/README.md)), or point `SHOPWARE_HOME_REPOS` elsewhere.
The first instance: `shopware-local-dev`, "Creating an instance".

Two caches make instances and worktrees cheap; both fill themselves on first use:

- the Docker volume `shopware-pkg-cache`: composer and npm download cache shared by every web container;
- `~/.shopware-nm/<lockfile hash>/`: installed `vendor/` and `node_modules` trees, cloned copy-on-write into instances and worktrees.

## Skills

```bash
git -C <home repo> submodule update --init
<home repo>/bin/install.sh --dry-run
```

It links every skill into `~/.agents/skills` (Codex reads it) and from there into `~/.claude/skills`, and the instance tools into `~/bin`.
It never overwrites: an existing skill of the same or an older name is reported, and migrating it is a decision for `setup-home`.

Third-party skills worth having, installed from their source rather than copied here:

```bash
npx skills add mattpocock/skills    # grilling, tdd, diagnosing-bugs, writing-for-agents, …
```

## Where sessions start

Start sessions in this repo, in its main checkout; it needs no worktrees of its own.
Code work happens in worktrees of the repos under `repositories/`, which the agent creates and attaches (`shopware-worktree-dev`).

What that changes, because the harness loads configuration from the session's directory and, on demand, from folders below it:

- **Memory** is keyed by git repository, so this repo starts with an empty one.
  Keep the memory you have: `"autoMemoryDirectory": "~/.claude/projects/<the old repo's slug>/memory"` in this repo's `.claude/settings.local.json` (gitignored, per machine).
- **A repo's own instructions** (`CLAUDE.md`, nested `AGENTS.md`, `.claude/rules/`, `.claude/skills/`) load once the agent touches a file in that repo.
- **A repo's own settings and hooks** do not load.
  What must apply goes into this repo's `.claude/settings.local.json`: `skillOverrides` for repo skills to switch off, `claudeMdExcludes` (absolute globs such as `**/repositories/shopware/*/AGENTS.md`) for a repo file a personal copy replaces.
  A Claude Code session can also move into the worktree (`/cd`, or the `EnterWorktree` tool), which loads its configuration fully.
- **User-level** instructions, rules (`~/.claude/rules/`), settings and hooks load everywhere, as before.

Sessions that still start inside a repo reach this one through a line in the global instructions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`):

```md
Shopware home (repos, setup, Shopware specifics for running, reviewing and babysitting PRs): <home repo>/AGENTS.md
```

## Personal context

Personal rules, preferences and per-repo patches stay out of this repo: in the global instruction files, the harness's memory, `~/.agents/github/preferences.md` for PR and issue defaults, `~/.agents/babysit/preferences.md` for babysitting, and `~/.agents/shopware-home/preferences.md` for the instances.

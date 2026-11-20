# Machine setup

What a Mac needs to run Shopware with agents the way this repo assumes.
The `setup-home` skill walks through it and adapts it; this is the reference.

## Tools

- [OrbStack](https://orbstack.dev) as the Docker runtime: it routes `<name>.orb.local` to containers without published ports.
- `git`, an authenticated [GitHub CLI](https://cli.github.com) (`gh auth login`), and [`gh stack`](https://github.com/github/gh-stack) for linked stacks.
- `python3` and `node` on the host for the scripts here; everything Shopware-related runs in the containers.
- A Playwright MCP server for browser work.

## Repos and instances

Clone what `AGENTS.md` lists into `~/Documents` (or set `SHOPWARE_HOME_REPOS`).
The first instance: `shopware-local-dev`, "Creating an instance".

Two caches make instances and worktrees cheap; both fill themselves on first use:

- the Docker volume `shopware-pkg-cache`: composer and npm download cache shared by every web container;
- `~/.shopware-nm/<lockfile hash>/`: installed `vendor/` and `node_modules` trees, cloned copy-on-write into instances and worktrees.

## Skills

```bash
git -C ~/Documents/shopware-home submodule update --init
~/Documents/shopware-home/bin/install.sh --dry-run
```

It links every skill into `~/.agents/skills` (Codex reads it) and from there into `~/.claude/skills`, and the instance tools into `~/bin`.
It never overwrites: an existing skill of the same or an older name is reported, and migrating it is a decision for `setup-home`.

Third-party skills worth having, installed from their source rather than copied here:

```bash
npx skills add mattpocock/skills    # grilling, tdd, diagnosing-bugs, writing-for-agents, …
```

## Reaching this repo from a session

Sessions usually start in a worktree of `shopware/shopware`, where this repo's `AGENTS.md` is not loaded.
One line in the global agent instructions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) makes it reachable:

```md
Shopware home (repos, setup, Shopware specifics for reviewing, running and babysitting PRs): ~/Documents/shopware-home/AGENTS.md
```

## Personal context

Personal rules, preferences and per-repo patches stay out of this repo: in the global instruction files, the harness's memory, and `~/.agents/babysit/preferences.md` for the PR skills.

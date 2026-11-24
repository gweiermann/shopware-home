---
name: maintain-home
description: The design decisions behind the shopware-home repo itself. Use before changing it - adding, moving or rewriting a skill, doc, script, hook or setting here - and when deciding whether something belongs in this repo, in one of the cloned repos, or in a person's untracked preferences.
---

# Maintain the home repo

This repo is public and generic: any Shopware developer clones it and gets a working agent setup.
Every change keeps it that way. Read the decisions below, then make the change so it fits them.

## Decisions

1. **Home Repo pattern.** Sessions start here, in the main checkout. The repo holds the map (which repos exist, how they connect), the shared skills, docs and tooling. Code lives in the repos under `repositories/`.
2. **Clean slate.** Repos are cloned fresh into `repositories/<name>` when first needed. Existing checkouts elsewhere on a machine are not adopted, moved or referenced; they are the person's business.
3. **Generic in the repo, personal outside it.** Anything specific to one person, machine or team (names, handles, absolute paths, labels, which instance to keep, merge habits, cadences) lives in an untracked file the skills read:

   | What | Where |
   |---|---|
   | Instances, PR defaults (labels, assignee) | `~/.agents/shopware-home/preferences.md` |
   | PR babysitting rules | `~/.agents/babysit/preferences.md` |
   | Harness settings for this repo (memory dir, `skillOverrides`, `claudeMdExcludes`) | `.claude/settings.local.json` (gitignored) |
   | Personal skills | `~/.agents/skills/<name>`, untracked |

   A skill that needs a personal answer reads it from there; when the answer is missing, it asks once and saves it. The repo text names the preference and gives a neutral example, never the answer itself.
4. **One home per kind of knowledge.**
   - True of one repo alone → that repo's own `AGENTS.md`, upstream.
   - Shopware-specific and useful to any Shopware developer → `skills/` here.
   - Generic, not Shopware → the `general/` submodule (`gweiermann/skills`).
   - Reference several skills share → `docs/`, reached by a pointer from `AGENTS.md` or a skill.
   - Cross-repo team conventions → `docs/conventions.md`.
   - Instance tooling → `bin/`.
5. **Pointers stay short.** `AGENTS.md` is always loaded: one line per repo, doc or skill group, each saying when to reach it. Detail goes into the doc or skill behind the pointer. Use the `writing-for-agents` skill for every skill or `AGENTS.md` edit.
6. **Install links, never overwrites.** `bin/install.sh` symlinks `skills/*` and `general/skills/*` into `~/.agents/skills` and `~/.claude/skills`. A skill that only matters while changing this repo (like this one) lives in `.agents/skills/` here, linked from `.claude/skills/`, so it loads only in sessions here. Migrating someone's existing setup is `setup-home`'s job.
7. **Instances are full checkouts.** Each `repositories/shopware/shopware-<n>` is a `trunk` checkout with its own Docker stack at `shopware-<n>.orb.local` (OrbStack), host ports offset by `index * 100`, at most three. `FEATURE_ALL: major` in its `compose.override.yaml` makes a 6.8 instance. Dependencies come from shared caches: the `shopware-pkg-cache` volume for downloads, `~/.shopware-nm/<lockfile hash>/` for installed trees, cloned copy-on-write. A new install step goes into `shopware-instance` and `attach.sh` through that store, so instances and worktrees stay in step.
8. **Worktrees live inside their repo**, in `<repo>/.claude/worktrees/<name>`: the Shopware container sees them, `link-local.sh` finds them, and `repositories/` lists only repos. `.claude/hooks/worktree-location.py` enforces it.
9. **Shared settings are minimal.** The tracked `.claude/settings.json` holds only what every clone needs (the worktree hook). Everything else is per machine in `settings.local.json`.
10. **Safe to publish.** No secrets, internal URLs, private repos, company assets (templates, decks), personal paths or names. Third-party code keeps its license file (`full-stop`, `opus-loop` from tstack, MIT).

## Before you finish

- The diff passes decision 10: `git diff` names no person (your own name, handle and home directory included) and no absolute home path, and every value that is one person's choice reads from a preferences file.
- `bin/install.sh --dry-run` still runs without new conflicts when you added, renamed or removed a skill.
- A changed script runs once for real (`bash -n` is not enough).

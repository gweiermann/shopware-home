---
name: setup-home
description: Set up or migrate a machine to the Shopware home repo - repos, instances, skills, preferences - adapted to the person's own work, and without losing what their current setup does. Use when someone is new to the home repo, when bin/install.sh reports conflicts, or when moving existing local skills and context onto it.
disable-model-invocation: true
---

# Set up the home repo

The goal is a machine where the home repo's skills, docs and tools run, adapted to this person, and where every session behaves at least as well as before.
Their current setup is the baseline: a migration that silently drops a behaviour is a regression.

Look up every fact yourself (filesystem, `git`, `gh`, subagents for wide searches) and bring the person only decisions.
Ask in rounds: number each question, give your recommendation, word it so "yes" accepts it.
Until they approve the plan, only read. Secrets stay unread.

## 1. Inventory

- **Repos**: which of `AGENTS.md`'s repos exist, where, on which branch; instances (`docker compose ls`, `devboard.py list`) and their domains.
- **Skills**: everything in `~/.claude/skills`, `~/.agents/skills`, `~/.codex/skills` and plugin marketplaces; where each link points.
- **Context**: global instruction files, memory directories, hooks in the harness settings, personal context tooling, state directories (a babysitting ledger, preferences).
- **Harnesses** in use (Claude Code, Codex, T3 Code, …): what each one loads, and where sessions usually start.

## 2. Compare

For every skill the home repo would install, find what it replaces: same name, or the same trigger under another name (`bin/install.sh --dry-run` reports both).
Diff each pair and sort every difference:

- **kept**: same behaviour, maybe shorter;
- **moved**: now in a doc or preference that a session must still reach (check the pointer that gets it there, from where sessions start);
- **dropped**: gone; say whether that is fine or must go into a preference, a doc or the person's own context;
- **references**: other skills, instruction files, memories and state that name the old skill, path or file.

Also check what the home repo assumes and this machine lacks (a primary instance, the caches, a pointer from the global instructions to the home repo).

## 3. Decide

Show one table: item → action (install, replace, keep theirs, leave out) → what changes for them.
Then ask for the answers the skills need, and whether to keep each for good or for this session only:

- which repos and how many instances (at most three), and whether any instance is theirs to test in and must keep its data (all disposable is a fine answer);
- PR defaults for `pr-create` (labels, assignee) and babysitting (`babysit-pr` and `babysit-all-prs` ask their own questions; seed their answers from the old setup's rules);
- where sessions start (here, or still inside the repos) and what that costs them: [docs/setup/machine.md](../../docs/setup/machine.md), "Where sessions start";
- the line pointing global instructions at the home repo.

Done when the person approved the table.

## 4. Apply

Back up before replacing: move every replaced skill and state file to `~/.agents/backup/<date>/`, never delete.
Run `bin/install.sh`, write the preferences, add the pointer, update references to old names.
A running long-lived session (a babysitting orchestrator) switches over in one step: migrate its state, then restart it on the new skill.

## 5. Verify

In a fresh session started where the person usually starts one:

- the expected skills are listed, and no two compete for one trigger;
- a worktree attaches to `READY` and its tests run;
- one real task per migrated skill behaves like before (a babysit wake, a review's environment step).

Report what changed, the backup path, and how to roll back (restore the backup, remove the links `install.sh` made).

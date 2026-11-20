# Repositories

Every repo `AGENTS.md` lists is cloned here, one folder per repo, named as `AGENTS.md` names it.
A missing one gets cloned when an agent first needs it: `git clone git@github.com:<remote>.git repositories/<name>`.

The clones are gitignored, so a search from the home repo's root skips them.
Search inside the repo: `rg <pattern> repositories/<name>`.

Sessions start in the home repo.
A repo's own `CLAUDE.md`, nested `AGENTS.md`, `.claude/rules` and `.claude/skills` load on demand once an agent touches a file in it.
Its `.claude/settings*.json` do not load; what must apply goes into the home repo's `.claude/settings.local.json`.

`shopware/` is the exception: it holds several checkouts of the same repo, see [shopware/README.md](shopware/README.md).

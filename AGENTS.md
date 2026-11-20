# Shopware home

The home repo for working on Shopware with agents: which repos exist and how they connect, the shared skills, the setup.
Code lives in each repo; anything true of one repo alone stays in that repo's own `AGENTS.md`.

New here, or something below is missing on this machine: `/setup-home` ([skills/setup-home](skills/setup-home/SKILL.md)) walks through it.

## Repos

Repos live in `repositories/<name>` (or `$SHOPWARE_HOME_REPOS/<name>`); [repositories/README.md](repositories/README.md) explains the layout.
Clone from `git@github.com:<remote>.git` if missing.
They are gitignored here, so search inside one: `rg <pattern> repositories/<name>`.
A repo's own `CLAUDE.md`, rules and skills load once you touch a file in it; its settings do not, the home repo's apply.

- Platform (`shopware/shopware`): `shopware/shopware-<n>`, one checkout per **instance** → `shopware-local-dev`, [repositories/shopware/README.md](repositories/shopware/README.md). Core, Administration, Storefront. Feature work happens in worktrees inside an instance → `shopware-worktree-dev`.
- SwagCommercial (`shopware/SwagCommercial`): `SwagCommercial`. Downstream of platform; companion PRs → `shopware-commercial-companion`.
- Rufus (`shopware/rufus`): `rufus`. Downstream like SwagCommercial.
- Meteor (`shopware/meteor`): `meteor`. The `mt-*` components; fix their bugs here → `shopware-worktree-dev`, "Fix it upstream".
- Acceptance test suite (`shopware/acceptance-test-suite`): `acceptance-test-suite`. Page objects and fixtures `tests/acceptance` imports.
- Docs (`shopware/docs`): `shopware-docs`. Developer documentation.
- Framework team (`shopware/framework-team`): `framework-team`. Team dashboard and the read-only `gh team` CLI.
- AI coding tools (`shopwareLabs/ai-coding-tools`): `ai-coding-tools`. The Labs Claude plugin marketplace.
- QA tool (`shopwareLabs/shopware-qa-tool`): `shopware-qa-tool`. Switch an instance to a branch, PR or tag.
- General skills (`gweiermann/skills`): the `general/` submodule here.

## Docs

- [docs/setup/machine.md](docs/setup/machine.md): tools, caches, installing the skills.
- [docs/run-a-pr.md](docs/run-a-pr.md): running, reviewing and babysitting a Shopware PR.
- [docs/review-surfaces.md](docs/review-surfaces.md): personas and surfaces for a user review.
- [docs/conventions.md](docs/conventions.md): team knowledge between the repos.

## Skills

`skills/` holds the Shopware skills, `general/skills/` the generic ones; `bin/install.sh` links both into place.
`bin/` holds the instance tooling (`shopware-instance`, `setup-shopware-instance.sh`).

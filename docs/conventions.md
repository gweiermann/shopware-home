# Conventions

Team knowledge that no config file confesses.
Repo-wide rules live in each repo's own `AGENTS.md` and `coding-guidelines/`; this file holds what sits between repos or in nobody's file.

## Git and PRs

- Once a PR has any review (a pending one too), changes go on top: no amend, no rebase, no force push. Bring the base in with a merge.
  Exception: a stack linked with `gh stack` must stay linear (its atomic merge rejects merge commits): `gh stack rebase`, `--force-with-lease`, each layer's diff unchanged afterwards.

## Administration

- `npm`, `npx` and jest run inside the instance container, never on the host (`@swc/core` ships Linux binaries only).
- A bug inside an `mt-*` component or an acceptance-test-suite helper is fixed in `meteor` or `acceptance-test-suite`, proven with `link-local.sh`, not wrapped or overridden in Shopware (`shopware-worktree-dev`, "Fix it upstream").

## Writing

- Code comments: one or two lines, the timeless *why*; nothing that needs the chat, the diff or the PR to make sense (`comment-hygiene`).
- Text for third parties (PR descriptions, issues, comments): `audience-aware-writing`.
- German snippets: "Du" in the Administration, "Sie" in the Storefront.

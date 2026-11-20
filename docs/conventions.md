# Conventions

Team knowledge that no config file confesses.
Repo-wide rules live in each repo's own `AGENTS.md` and `coding-guidelines/`; this file holds what sits between repos or in nobody's file.

## Git and PRs

- Once a PR has any review (a pending one too), changes go on top: no amend, no rebase, no force push. Bring the base in with a merge.
  Exception: a stack linked with `gh stack` must stay linear (its atomic merge rejects merge commits): `gh stack rebase`, `--force-with-lease`, each layer's diff unchanged afterwards.
- Breakage on trunk or in the merge queue that the PR did not cause is not ours to fix: no fix PR, no commit on our branch. Wait, then bring trunk in and retry.
- A follow-up in the same repo goes into the open draft, not a new PR. A PR is never superseded by a replacement; push to the draft or insert a layer into the stack.
- `gh pr ready` only when the user says so.

## Administration

- `npm`, `npx` and jest run inside the instance container, never on the host (`@swc/core` ships Linux binaries only).
- A bug inside an `mt-*` component or an acceptance-test-suite helper is fixed in `meteor` or `acceptance-test-suite`, proven with `link-local.sh`, not wrapped or overridden in Shopware (`shopware-worktree-dev`, "Fix it upstream").
- A deprecation sweep skips hosts that are themselves deprecated; they keep their baseline entry.
- `<script setup>` migration: setup APIs only for features every page hits (`shortcuts`, `metaInfo`, `ExtensionAPI.publishData`); a component whose mixin has no composable twin stays on the Options API, no bridge.
- Codemod work fixes the codemod, never hand-edits the components it should migrate.

## Writing

- Code comments: one or two lines, the timeless *why*; nothing that needs the chat, the diff or the PR to make sense (`comment-hygiene`).
- Text for third parties (PR descriptions, issues, comments): `audience-aware-writing`.
- German snippets: "Du" in the Administration, "Sie" in the Storefront.

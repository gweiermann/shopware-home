---
name: shopware-breaking-changes
description: Decide whether a change is actually a breaking change, using origin/trunk as the only baseline. Use before adding a deprecation, BC layer, fallback, alias, or compatibility shim; when you are about to call code "legacy" and migrate it; when you think or write "this is a breaking change", "for backwards compatibility", "existing usages", "keep both paths working", or "extensions might rely on this"; and when deciding whether an UPGRADE entry is needed.
license: MIT
---

# Shopware Breaking Changes

**`origin/trunk` is the only baseline.** A change is breaking only if it removes, renames, or changes the observable behaviour of public API that exists in `origin/trunk` right now.

Nothing in your working tree, your branch, or the PRs below you in a stack is a baseline. If an API was introduced by unmerged commits — yours or an earlier PR in the same stack — it has no outside consumers, so changing or deleting it is ordinary editing, not a break.

## The test — run it, don't reason about it

```bash
git fetch origin trunk && git diff origin/trunk...HEAD -- <path>
```

```bash
git show origin/trunk:<path>
```

Then answer in order:

1. **Does the symbol exist in `origin/trunk`?** No → not breaking. Stop here: no deprecation, no BC layer, no `UPGRADE` entry.
2. **Is it public in trunk?** `@internal`, `private`, test-only, or a file that only exists on your branch → not breaking.
3. **Would a third party pinned to released Shopware observe a difference?** No → not breaking.

Only if all three are yes do you have a breaking change. Then follow `shopware-release-docs` and the deprecation rules in `shopware-php-code`.

## Catch phrases — say it, then check trunk

Each of these is a signal you are about to build a BC layer against something that was never released. When one of these sentences forms, run the test above before writing a line of code.

| If you catch yourself thinking or writing… | Do this instead |
|---|---|
| "This is legacy code, let me migrate it" | "Legacy" is a fact about `origin/trunk`, not a vibe. If the pattern is not in trunk, there is nothing to migrate — just change it. |
| "For backwards compatibility, I'll keep the old method" | Name the trunk file and line that provides the old method. Cannot name it? Delete it. |
| "This would be a breaking change" | Finish the sentence: breaking *against what*. Quote `git show origin/trunk:<path>` or drop the claim. |
| "I'll deprecate the old option and add the new one" | Deprecations exist for API that shipped to users. Never deprecate API that never existed in trunk. |
| "Both paths should keep working" | Grep the usages. If every hit is inside `git diff origin/trunk...HEAD`, there are no existing usages. |
| "I'll add a fallback / alias / shim / adapter for the old shape" | A shim over a same-branch API is dead code on arrival. Change the callers in the same commit. |
| "Let me preserve the current behaviour" | Current *where*? Working tree ≠ baseline. Only trunk behaviour is promised. |
| "Extensions in the wild might rely on this" | Not for `@internal`, `private`, or unreleased code. For genuinely public trunk API, say so explicitly and cite it. |
| "This looks like an old pattern, I'll modernise the callers too" | Out of scope unless the callers are broken. See `shopware-change-scope`. |
| "The signature changed, so I need a BC-safe overload" | Only if the old signature is in trunk and public. Otherwise edit the signature. |
| "Tests are failing, so this is breaking" | Tests you added on this branch failing is churn — fix the tests. A trunk test failing is a signal; check whether it asserts a public contract before calling it a break. |
| "I'll add an `UPGRADE-6.x` entry for the removed option" | Nothing was removed from the outside view. Instead correct the `RELEASE_INFO` entry the earlier stack commit already added for that feature. |
| "Keep the old file/class as a re-export for compatibility" | Only for public trunk paths. A branch-local move is just a move. |
| "I'll rename it but leave the old name working" | Same test. Old name not in trunk → rename it and be done. |

## Stacked PRs

In a stack (`feature/01-…` → `feature/02-…` → …) the baseline is still `origin/trunk`, never the parent branch. PR 03 freely reshapes API that PR 01 introduced. What that *does* require: fixing the earlier PR's own callers, tests, and its `RELEASE_INFO` wording so the stack reads as one coherent change — not a deprecation of your own unmerged work.

## Nuance worth flagging, not solving alone

Code that is merged to trunk but not yet in a released tag is not a promise to released consumers. Do not build a compat layer for it unprompted — mention it in the PR description and let a human decide.

## When it really is breaking

Report it plainly instead of quietly wrapping it. See `references/BREAKING-SURFACE.md` for what counts as public surface (PHP, DAL, HTTP APIs, Twig, SCSS, Admin JS, snippets, config) and for worked examples of each verdict.

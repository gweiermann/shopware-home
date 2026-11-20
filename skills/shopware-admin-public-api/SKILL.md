---
name: shopware-admin-public-api
description: Decide, detect and document changes to the Shopware Administration's public API for extension authors - before adding a deprecation, BC layer, fallback, alias or shim; when calling code "legacy", "breaking" or "for backwards compatibility"; when reviewing a diff under src/Administration for removed or changed Twig/sw-block blocks, components, props, emits, slots, methods, setup API, directives, refs, assets, SCSS selectors, extension SDK positions and data sets, services, stores, routes or ACL privileges; and when deciding or writing RELEASE_INFO / UPGRADE-6.8.md entries for an Administration change.
license: MIT
---

# Shopware Administration Public API

Find what a third-party plugin, app or theme would notice after an Administration change ships, and document exactly that, nothing more.

Scope: `src/Administration/Resources/app/administration/**`.

The normative rules are the Administration tables in the [Shopware backward-compatibility guideline](https://developer.shopware.com/docs/resources/guidelines/code/backward-compatibility.html#administration).
`references/CATALOG.md` carries them plus the cases this repository's extension mechanics add; where the two disagree, the guideline wins.

## The baseline test

The PR base branch (usually `origin/trunk`) is the only baseline.
Nothing in the working tree, the branch, or an earlier PR in the same stack counts.

```bash
git fetch origin trunk && BASE=$(git merge-base origin/trunk HEAD)
git show $BASE:<path>
```

For each candidate, answer in order and stop at the first `no`:

1. **Does the symbol exist at `$BASE`?** No → not breaking. No deprecation, no BC layer, no entry.
2. **Is it public there?** `@private`, `@internal`, `@experimental`, behind an unreleased feature flag, or test-only → not breaking.
   Administration components carry no `@public` marker: **absence of `@private` is the contract**.
3. **Would a third party on a released Shopware observe a difference?** No → not breaking.

Only when all three are yes do you have a breaking change.

- **Stacked PRs:** the baseline is still `origin/trunk`, never the parent branch.
  A later PR freely reshapes API an earlier PR in the stack introduced; fix that PR's callers and its `RELEASE_INFO` wording instead of deprecating unmerged work.
- **Merged but unreleased:** code on trunk that has not shipped in a tag is no promise to released consumers.
  Don't build a compatibility layer for it unprompted; flag it in the PR and let a human decide.
- **Feature-flag branches:** removing something inside a `v6.8.0.0` branch **is** the 6.7 → 6.8 break, and `UPGRADE-6.8.md` documents it.

## Catch phrases: say it, then check

When one of these sentences forms, in your reasoning or in a PR description, run the check next to it.

| If you catch yourself thinking or writing… | Do this instead |
|---|---|
| "This is legacy code, let me migrate it" | "Legacy" is a fact about `$BASE`. Not in the base → just change it. |
| "For backwards compatibility, I'll keep the old one" / "both paths should keep working" | Name the base file and line that provides it. Can't → delete it and change the callers in the same commit. |
| "I'll add a fallback / alias / shim / re-export for the old shape" | Only for public API at `$BASE`. A shim over a branch-local API is dead on arrival. |
| "I only renamed it" | A rename is a removal plus an addition; the old name is what shipped. |
| "I moved the block, I didn't delete it" | Moving across a parent block or a file changes the override's data scope (§1.4). |
| "CI is green, so nothing broke" | Guards exist only for blocks, position identifiers and data sets. Nothing guards props, emits, slots, methods, SCSS, assets, routes or ACL. |
| "The block is still in `blocks-list.json`" / "I'll just regenerate the baseline" | Diff the baseline file itself; a removed line is a confirmed break that regenerating only silences. |
| "It's only a markup change" | Root selectors, `is--*` and the seven structural properties are contract (§11). |
| "Nobody overrides this component" | You can't know that. Absence of `@private` is the contract. |
| "It's behind the `v6.8.0.0` flag, so it's internal" | Removing a flagged branch is the 6.7 → 6.8 break. |
| "The shim keeps Options overrides working" | Not for `provide`, `components`, `directives`, `emits`, custom `render()`, or dot-notation `watch` (§5.19). |
| "The file is still in git" | Assets are emitted because something imports them. Drop the last import and the URL 404s (§10.3). |
| "That's a Vue-internal detail" | `ref`, `v-model`, `v-bind` and `v-if` are listed as not-allowed changes (§2). |
| "It's just the default value" | Call-out, unless existing usages relied on it; then it is breaking (§5.7). |
| "Tests are failing, so this is breaking" | Specs added on this branch failing is churn. A base spec failing is a signal; check whether it asserts a public contract. |
| "I'll deprecate it and remove it in the same PR" | Deprecation buys a major-version window. Removing in the same release is just a removal. |
| "Snippet keys are API too" | They are not (§6). |

## Review workflow

1. **Scope the diff.** `git diff $BASE HEAD --name-only -- src/Administration/Resources/app/administration`; drop `*.spec.*`, `.spec/`, `test/` and fixtures.
2. **Walk the whole surface checklist below**, every row, every time.
3. **Classify each candidate** against `references/CATALOG.md`: `breaking`, `partial`, `call-out` or `not-breaking`.
4. **Verify against the base** with `git show $BASE:<path>` and the baseline test, then name the concrete extension code that breaks. A finding without a broken caller shape is noise.
5. **Check the documentation** per "Release docs" below. A missing `UPGRADE-6.8.md` entry for a `breaking` finding is itself a finding; draft it.

## Surface checklist

Sweeps are in `references/DETECTION.md`, verdicts in `references/CATALOG.md`.

| # | Surface | Look for |
|---|---|---|
| 1 | Committed baselines | Removed lines in `blocks-list.json`, `src/meta/position-identifiers.json`, `src/meta/data-sets.json` |
| 2 | Twig blocks | Removed, renamed, moved, emptied, wrapped, re-nested, converted to SFC or `sw-block` |
| 3 | Template directives | `v-if` chains, `v-model`, `v-bind`/`:prop`, `v-for` variables, `ref` |
| 4 | Native `sw-block` | Removed names, dropped `:data="$dataScope"`, placement inside `v-for` / condition chains / slot boundaries |
| 5 | Components | Removed, renamed, newly `@private`, rewrapped around `mt-*`, changed `extend` parent |
| 6 | Component API | Props, emits, slots, methods, computeds, `data()` keys, mixins, `public`/`private` setup split, `ComponentPublicApiMapping` |
| 7 | Extension SDK | Position identifiers, published data set ids **and payload shape**, location ids, new privilege requirements |
| 8 | Global object | Services and their signatures, stores and their keys, filters, directives, mixins, `globalProperties` helpers, API service request/response shape |
| 9 | Modules, routes, ACL | Route names, paths, params, new required params, menu ids and parents, privilege keys |
| 10 | Assets and imports | Deleted, renamed, moved, format-migrated, **and assets that lost their last import** |
| 11 | Styling | Root selectors, `is--*` selectors, the seven structural properties |
| 12 | Documentation | Every `breaking` finding has its `UPGRADE-6.8.md` entry |

Report a one-line coverage note (`checked 1–12, findings on 2, 6, 10`) so a skipped surface is visible.

## Verdicts

| Verdict | Meaning | Required action |
|---|---|---|
| `breaking` | Public Administration API from the base is gone or behaves differently for an existing extension | `UPGRADE-6.8.md` entry, plus a migration path or a deprecation shape from `references/DEPRECATION-PATTERNS.md` |
| `partial` | Permitted under one stated condition: a new optional parameter with a default, a move inside the same parent block, a purely visual CSS property | Check the condition holds; if not, treat as `breaking` |
| `call-out` | Extensions can plausibly break but never had a contract: descendant CSS classes, DOM order, repurposed block semantics | Mention in the PR description; entry only if a concrete extension pattern breaks |
| `not-breaking` | Not in the base, `@private`, experimental, test-only, or a snippet key | Nothing; don't report it |

## Release docs

Document only what changes for people outside the repo: extension and app authors, theme developers, API consumers, operators.
Skip narrow bug fixes, implementation-only refactors and test-only changes.

- **`RELEASE_INFO-6.<current minor>.md`:** a short entry in the upcoming section under the matching category, telling third-party developers what changed and how to adopt it.
  Add one when extension authors benefit from knowing early, including every new deprecation.
- **`UPGRADE-6.8.md`:** answers one question: must existing extension code change to keep working after the major?
  Yes → an entry under `# Administration` with the concrete before and after; this covers removals, breaking changes and deprecations (written in the PR that introduces the deprecation).
  No → nothing, however large the change; a bug fix that restores intended behaviour needs no entry either.
  Wording and templates are in `references/UPGRADE-ENTRIES.md`.

Write from the outside reader's view: what changed, who is affected, what to do.
Add a sentence on *why* only when it tells them how urgent the change is (a bug, security, performance).
Write past tense, as readers see it after the release: "`sw-foo` was deprecated and is removed in 6.8. Use `sw-bar`."

Formatting: a blank line around every heading and between paragraphs; the entry goes under the existing category heading of the upcoming version section, and a heading is never repeated inside one section (the `release-info/section` check rejects it); code snippets in the shortest form a developer can copy.

## Output of a review

Compact Markdown, most severe first, one block per finding:

```markdown
- **breaking · twig-block** `src/module/sw-product/page/sw-product-detail/sw-product-detail.html.twig:88`: `sw_product_detail_content_tabs` removed
  Breaks: `Shopware.Component.override('sw-product-detail', { template: '{% block sw_product_detail_content_tabs %}{% parent %}…' })`, the override is dropped silently.
  Evidence: block present at `$BASE`, absent in `blocks-list.json` diff.
  Fix: keep the block wrapping the new markup, or rename with the old block retained as an alias for 6.8.
  UPGRADE-6.8.md: missing, draft below.
```

Close with the coverage note, then the drafted entries or `_No breaking changes._`.

## References

- `references/CATALOG.md`: every surface, what breaks it, and the verdict.
- `references/DETECTION.md`: copy-pasteable sweeps per surface.
- `references/DEPRECATION-PATTERNS.md`: the deprecation shape to propose for each kind of break.
- `references/UPGRADE-ENTRIES.md`: wording rules and templates for `UPGRADE-6.8.md`.

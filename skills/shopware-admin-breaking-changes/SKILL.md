---
name: shopware-admin-breaking-changes
description: Detect breaking changes for extension authors in Shopware Administration diffs during a PR review. Use when reviewing a PR or local diff that touches src/Administration — removed or repurposed Twig/sw-block blocks, removed or privatised components, changed props, emits, slots, methods or setup public API, changed template directives and refs, deleted or renamed asset files and SCSS partials, functional CSS selectors, extension SDK position identifiers and data sets, services, stores, routes or ACL privileges — and to draft the required UPGRADE-6.8.md entry.
license: MIT
---

# Shopware Administration Breaking Changes

Find what a third-party plugin, app or theme would notice after this diff ships, and make sure it is documented.

Scope: `src/Administration/Resources/app/administration/**`. For PHP, Storefront, DAL or HTTP API surfaces use `shopware-breaking-changes` instead.

The normative rules are the Administration compatibility tables in the [Shopware backward-compatibility guideline](https://developer.shopware.com/docs/resources/guidelines/code/backward-compatibility.html#administration). `references/CATALOG.md` carries them plus the cases this repository's extension mechanics add on top; where the two ever disagree, the guideline wins.

## The baseline test

The PR base branch (usually `origin/trunk`) is the only baseline. Nothing in the working tree, the branch, or an earlier PR in the same stack counts.

```bash
git fetch origin trunk && BASE=$(git merge-base origin/trunk HEAD)
```

For each candidate, answer in order and stop at the first `no`:

1. **Does the symbol exist at `$BASE`?** No → not breaking. No deprecation, no entry.
2. **Is it public there?** `@private`, `@internal`, `@experimental`, behind an unreleased feature flag, or test-only → not breaking. Administration components carry no `@public` marker: **absence of `@private` is the contract**.
3. **Would a third party on a released Shopware observe a difference?** No → not breaking.

Only when all three are yes do you have a finding.

**Stacked PRs:** the baseline is still `origin/trunk`, never the parent branch. A later PR freely reshapes API an earlier PR in the same stack introduced — what that does require is fixing the earlier PR's own callers and its `RELEASE_INFO` wording, not deprecating your own unmerged work.

**Merged but unreleased:** code on trunk that has not shipped in a tag is not a promise to released consumers. Do not build a compatibility layer for it unprompted — flag it in the PR and let a human decide.

**Feature-flag branches are the exception to "it looks internal":** removing something inside a `v6.8.0.0` branch **is** the 6.7 → 6.8 break. That is exactly what `UPGRADE-6.8.md` documents.

## Workflow

1. **Scope the diff.** `git diff $BASE HEAD --name-only -- src/Administration/Resources/app/administration` — drop `*.spec.*`, `.spec/`, `test/`, fixtures.
2. **Walk the whole checklist below.** Every surface, every time. Most PRs touch three or four; the ones that get missed are the ones nobody thought to look at.
3. **Classify each candidate** against `references/CATALOG.md`: `breaking`, `partial`, `call-out`, or `not-breaking`.
4. **Verify against the base** before reporting: `git show $BASE:<path>`. Run the three-question test. Then name the concrete extension code that breaks — a finding without a broken caller shape is noise.
5. **Check the documentation.** Every `breaking` finding needs an entry in `UPGRADE-6.8.md` under `# Administration`. Missing entry is itself a review finding; draft it using `references/UPGRADE-ENTRIES.md`.

## Mandatory surface checklist

Run every row. Sweeps are in `references/DETECTION.md`; verdicts in `references/CATALOG.md`.

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
| 10 | Assets and imports | Deleted, renamed, moved, format-migrated — **and assets that lost their last import** |
| 11 | Styling | Root selectors, `is--*` selectors, the seven structural properties |
| 12 | Documentation | Does every `breaking` finding have its `UPGRADE-6.8.md` entry? |

Report a one-line coverage note (`checked 1–12, findings on 2, 6, 10`) so a skipped surface is visible. Coverage is not findings — do not pad the findings list to fill the table.

## Catch phrases — say it, then check

Each of these is the moment a real break gets waved through. When one of these sentences forms, in your reasoning or in the PR description, run the check next to it.

| If you catch yourself thinking or writing… | Do this instead |
|---|---|
| "CI is green, so nothing broke" | Three guards exist, for blocks, position identifiers and data sets. **Nothing** guards props, emits, slots, methods, SCSS, assets, routes or ACL. |
| "The block is still in `blocks-list.json`" | That file is a committed baseline. Diff the file itself — a removed line is a confirmed break somebody regenerated away. |
| "I'll just regenerate the baseline" | That silences the guard, not the break. |
| "It's only a markup change" | Root selectors, `is--*` and the seven structural properties are contract (§11). |
| "I only renamed it" | A rename is a removal plus an addition. The old name is what shipped. |
| "I moved the block, I didn't delete it" | Moving across a parent block or a file changes the override's data scope (§1.4). |
| "Nobody overrides this component" | You cannot know that. Absence of `@private` is the contract, not usage evidence. |
| "It's behind the `v6.8.0.0` flag, so it's internal" | Removing a flagged branch **is** the 6.7 → 6.8 break. |
| "The shim keeps Options overrides working" | Not for `provide`, `components`, `directives`, `emits`, custom `render()`, or dot-notation `watch` (§5.19). |
| "The file is still in git" | Assets are emitted because something imports them. Drop the last import and the URL 404s (§10.3). |
| "That's a Vue-internal detail" | `ref`, `v-model`, `v-bind` and `v-if` are all listed as not-allowed changes (§2). |
| "It's just the default value" | Call-out — unless existing usages relied on it, then it is breaking (§5.7). |
| "Snippet keys are API too" | They are not. Explicitly out of scope — see §6. |
| "I'll deprecate it and remove it in the same PR" | Deprecation buys a major-version window. Removing in the same release is just a removal. |
| "It's breaking, so I'll add a BC layer" | First run the three-question test. If the symbol is not at `$BASE`, there is nothing to preserve — just change it. |

## Verdicts

| Verdict | Meaning | Required action |
|---|---|---|
| `breaking` | Public Administration API from the base is gone or behaves differently for an existing extension | `UPGRADE-6.8.md` entry, plus a migration path or a deprecation from `references/DEPRECATION-PATTERNS.md` |
| `partial` | The compatibility sheet permits it under one stated condition — a new optional parameter with a default, a move inside the same parent block, a purely visual CSS property | Check the condition holds. It does not → treat as `breaking` |
| `call-out` | Extensions can plausibly break but never had a contract — descendant CSS classes, DOM order, repurposed block semantics | Mention in the PR description; entry only if a concrete extension pattern breaks |
| `not-breaking` | Not in the base, `@private`, experimental, test-only, or a snippet key | Nothing — do not report |

Do not report `not-breaking` candidates. Do not pad the list.

For every `breaking` finding, propose the concrete deprecation shape rather than "deprecate it instead" — the shapes are in `references/DEPRECATION-PATTERNS.md`.

## Output

Compact Markdown, most severe first, one block per finding:

```markdown
- **breaking · twig-block** `src/module/sw-product/page/sw-product-detail/sw-product-detail.html.twig:88` — `sw_product_detail_content_tabs` removed
  Breaks: `Shopware.Component.override('sw-product-detail', { template: '{% block sw_product_detail_content_tabs %}{% parent %}…' })` — the override is dropped silently, no error.
  Evidence: block present at `$BASE`, absent in `blocks-list.json` diff.
  Fix: keep the block wrapping the new markup, or rename with the old block retained as an alias for 6.8.
  UPGRADE-6.8.md: missing — draft below.
```

Close with the coverage note, then either the drafted `UPGRADE-6.8.md` entries or `_No breaking changes._`.

## References

- `references/CATALOG.md` — every surface, what breaks it, and the verdict.
- `references/DETECTION.md` — copy-pasteable sweeps per surface.
- `references/DEPRECATION-PATTERNS.md` — the deprecation shape to propose for each kind of break.
- `references/UPGRADE-ENTRIES.md` — wording rules and templates for `UPGRADE-6.8.md`.

## Related

- `shopware-breaking-changes` — the general trunk-baseline test for non-Administration surfaces.
- `shopware-release-docs` and `shopware-admin-js` — release-doc wording and Administration coding rules. These ship with the Shopware repository, so they resolve only inside a checkout.

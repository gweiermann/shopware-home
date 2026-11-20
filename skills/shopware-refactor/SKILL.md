---
name: shopware-refactor
description: Aggressively refactor Shopware code for readability and structure — Single Level of Abstraction (SLAP), dead code removal, de-duplication, and simplifying over-engineered code. Use when asked to refactor, clean up, restructure, tidy, simplify, or improve the readability of existing code; when a function or class is too long, too nested, or mixes altitudes; when duplication or unused code should go; or when something looks over-engineered.
license: MIT
---

# Shopware Refactor

**Behaviour stays identical. Everything else is negotiable.**

Refactoring here is aggressive by default: rewrite whole functions, classes, and file layouts on the current branch, and change other files when the cut demands it. `origin/trunk` is the only baseline — public API introduced by unmerged commits needs no deprecation, no alias, no BC shim, no migration path. Before you write any compatibility layer, run the test in `shopware-breaking-changes`.

## Workflow

1. **Read every touched file end to end.** Not the diff, not the region around the smell. Then read the callers, the tests, and the string-based wiring (§Before you rename). Altitude cannot be judged from an excerpt, and Shopware wires a lot of things by name rather than by symbol.
2. **Name the mechanism.** One plain sentence per file: what it actually does, and where the altitudes collide. If you cannot say it yet, keep reading.
3. **Plan the cuts** in four buckets: SLAP splits, dead code, duplication, over-engineering. Take the over-engineering bucket to the user (§Approval) before deleting capability; do the rest yourself.
4. **Refactor in small commits, each one green.** Behaviour-preserving moves never share a commit with a behaviour fix. If you find a bug on the way, say so and keep it separate.
5. **Verify parity.** Existing tests must pass *unmodified*. A test you had to change is a claim that behaviour changed — justify it in the commit, or revert the cut. Then lint every touched file (AGENTS.md → File Linting).
6. **Report** what you removed, what you moved, what you deliberately left, and why.

## SLAP — the main principle

1. **One altitude per function.** A function is either *policy* (a list of named steps) or *mechanism* (the loop arithmetic, the SQL, the byte fiddling) — never both. Read it aloud: if the prose changes floors mid-sentence, split it.
2. **Never reach up.** Descending into detail is fine; a helper that dispatches events, decides business policy, or logs audit trails has grown a caller's responsibility and can no longer be reused or tested alone.
3. **Extract only what earns a name.** The new name must say something the body doesn't. If the best name is `doTheLoop()`, the mixing was cheaper than the indirection.
4. **Step-down order.** Callers above callees; each level narrates the one below, so a reader can stop at any level and still have a true summary.
5. **Tells, in order of cheapness:**

| Tell | Why it fires | Cut |
|---|---|---|
| Section comments inside a body (`// validate`, `// then persist`) | The comment is naming a step the code refused to name | Each section becomes a named callee |
| Domain vocabulary next to `$bytes[3]`, a raw SQL string, or `Criteria` plumbing | Policy and mechanism in one breath | Push the mechanism down one level |
| Presentation policy inside a data path — notifications, translations, routing, event dispatch | The callee grew the caller's job (rule 2) | Return or throw; let the caller decide what it means |
| Nesting past two levels | Control flow is doing the work a name should do | Guard clauses, early return, extract the inner block |
| A name that needs "and" (`validateAndSave`) | Two altitudes, or two responsibilities | Split at the "and" |

Worked before/after examples live in the reference for the language you are in — read the matching one before the first split:

- [`references/SLAP-ADMIN-JS.md`](references/SLAP-ADMIN-JS.md) — Administration JS/TS/Vue: where an extracted piece belongs (computed → method → component → composable → service → store), the fat-component split, the template as its own altitude, Admin-specific tells.
- [`references/SLAP-PHP.md`](references/SLAP-PHP.md) — PHP: policy vs. `Criteria`/SQL mechanism, when mechanism earns its own `@internal` class, PHP-specific tells.

## Also in scope, every time

- **Clean code basics** — intention-revealing names, no output parameters, no boolean flag parameters that select behaviour, no comments restating code, consistent vocabulary for one concept, small classes with one reason to change.
- **Dead code — delete it.** Unused private methods, unreachable branches, orphaned `@internal` classes, unregistered services, unused snippets, SCSS, Twig blocks, imports, exports.
- **Duplication — fix it once.** Extract into the nearest existing home before inventing a new abstraction, and leave *accidental* duplication alone: two bodies that look alike but change for different reasons are not duplicates.
- **Over-engineering — simplify, with approval.** See below.

Detection commands, the duplication rules, and the over-engineering catalogue are in [`references/SMELLS.md`](references/SMELLS.md).

## Over-engineering: ask before you drop capability

In Shopware, extension surface *is* a feature. An interface with one implementation, an event with no in-repo listener, or a seam that looks pointless may be a deliberate extension point — check `@final`, `@internal`, and the decorator pattern (`coding-guidelines/core/final-and-internal.md`, `extendability.md`, `decorator-pattern.md`) before calling it waste. Anything not `@internal` and reachable from a plugin is a feature until a human says otherwise.

In the Administration the same holds for `{% block %}` names in `.html.twig` templates, component names registered via `Component.register`, and anything marked `@public` — plugins override by name, so an unused-looking block is still a contract.

**Approval protocol.** Collect every candidate, then ask *once*, in one message. Per candidate give: what it is, what it serves today (with evidence — callers, listeners, extension surface), what would be lost, and the simpler shape you propose. When the evidence is thin, default to keeping it and say so. Never quietly drop a capability because it looked unused.

## Before you rename or delete anything

Symbol-level grep is not enough — Shopware references a lot of code by string. Check all of these for the old name:

```bash
git grep -n "OldName" -- '*.php' '*.xml' '*.yaml' '*.yml' '*.twig' '*.js' '*.ts' '*.vue' '*.scss' '*.json'
```

DI service ids and tags, Twig template and block names, `Component.register`/`Component.override` names and `sw-*` component tags, snippet keys, ACL privilege keys, event name constants, feature-flag names, `Criteria` field paths and DAL association names, migration class names, and test fixtures. A rename that misses one of these compiles and passes unit tests while breaking at runtime.

## Guardrails

- No behaviour change, no API redesign, no new features hidden in a refactor commit.
- No deprecations, aliases, or fallbacks for API that is not in `origin/trunk` (`shopware-breaking-changes`).
- Do not "modernise" a file you were not asked to touch just because it is nearby — see `shopware-change-scope` for how far to reach.
- Language-specific rules still apply: `shopware-php-code` for PHP, `shopware-admin-js` for Admin JS/TS/Vue, `shopware-phpunit-tests` for PHPUnit.
- Behaviour is unchanged, so release docs are usually unnecessary — but if a public signature in `origin/trunk` moved, check `shopware-release-docs`.
- Commit conventionally with scope, e.g. `refactor(core): split cart persister policy from SQL`.

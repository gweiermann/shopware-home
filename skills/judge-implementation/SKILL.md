---
name: judge-implementation
description: Judge how a Shopware PR or diff is built - its impact and risk, the patterns it uses and whether Shopware or the industry already knows them, what it duplicates instead of reusing, how much of a quick fix it is, and whether it should be split into a PR stack. Use when asked to judge or rate an implementation or approach, "is this a hack?", "is this the Shopware way?", or "should this PR be split?".
---

# Judge implementation

A static judgement of _how_ a change is built, read from the code.
It proves nothing at runtime; for verified bugs, run `pr-review`.

Target: a PR number, a branch, or the local diff.
Get the full diff against its base (`gh pr diff <n>`, or `git diff <base>...<head>`) and read every changed file end to end, not just the hunks.

## 1. Impact

Assess it the way `pr-review` step 6 does (`~/.agents/skills/pr-review/SKILL.md`): public API, breaking changes, affected, risk.
For what counts as public API and as breaking, apply `shopware-breaking-changes`, and `shopware-admin-public-api` for anything under `src/Administration`.

## 2. Pattern inventory

A **pattern** is a recurring solution shape the change relies on: an event subscriber, a decorator, a DAL entity extension, a message handler, a feature flag, a migration, a composable, a Pinia store, a mixin, a cache layer, a retry loop, a hand-rolled parser.
List every pattern the change introduces or newly applies, one line each, with the file:line where it lives.
The step is done when every new class, function, service definition, subscriber, store, and config key in the diff belongs to a listed pattern.

## 3. Judge each pattern

Every judgement carries its evidence: a quoted line and a link, or a search with its hit count.

1. **Shopware**: does the codebase already solve this problem this way?
   Search `src/` for the same shape (`rg -l`), and name the hit count and two representative examples.
   Then check `coding-guidelines/`, `adr/`, and the nearest `AGENTS.md` for a rule that blesses, deprecates, or forbids it.
   A pattern Shopware has deprecated or replaced (a newer ADR, a `@deprecated` sibling) counts as against the convention, however many hits it still has.
2. **Industry**, only when Shopware does not use it: name the pattern and a primary reference (Symfony, Vue, Doctrine, PHP-FIG, MDN, a well-known book).
   A pattern known in the industry but against a Shopware rule (Doctrine ORM or QueryBuilder instead of the DAL, a decorator where an event fits) is worse than an unknown one: say so.
3. **Verdict**: _house pattern_ (established in Shopware), _industry pattern_ (new to Shopware, known elsewhere), _against convention_, or _novel_ (neither: the reviewer has to learn it from this PR alone).

## 4. Reuse

For every new function, method, helper, constant, type, and component in the diff, search for an existing one that does the same job: same name stem, same signature, same behaviour under another name.
Search the module first, then the bundle, then `src/` (Admin: also `src/app/service`, `src/core`, `src/app/composables`, and the Meteor `mt-*` components).
Report each duplicate with both locations and how closely they match (identical / same job, other edge cases / overlapping).
Also report the reverse: an existing helper the change reuses although it does not quite fit, bent with extra flags or parameters.
The step is done when every new symbol has a match or a "no existing equivalent" with the search that proves it.

## 5. Quick-fix scale

Place the change on one rung and quote the line that decides it:

1. **Root-cause fix**: changes the place where the wrong behaviour originates; every caller benefits.
2. **Targeted fix**: right layer, but covers only the reported path; siblings with the same flaw stay (name them).
3. **Patch**: corrects the symptom downstream of the cause (a guard, a fallback, a re-sort, a `?? []`).
4. **Workaround**: routes around the flaw (a timeout, a retry, a duplicated code path, a special case for one entity or one extension).
5. **Hack**: depends on an accident of the current code (internal state, call order, a magic string, a CSS selector of another component).

Use `shopware-change-scope` to locate the root cause before you rate.

## 6. Stack split

Count the independent concerns in the change: patterns from step 2, plus refactors, renames, moved files, and test-only changes.
Propose a stack when two or more of them can each land green on their own:

- Order the layers so each one depends only on the layers below it.
- Typical cuts: preparatory refactor or rename → new extension point or service → the behaviour change → its call sites and cleanup.
- For each layer give its files, its one-line purpose, and whether it is reviewable alone (a reviewer can judge it without the next layer).

Say "keep as one PR" when a layer cannot stand alone, or the whole change is one pattern; give the reason.

## 7. Report

Quote and link every claim.
Run it through the `humanizer` skill before handing it over.

````markdown
## Impact and blast radius
- Public API: … (or "none")
- Breaking changes: … (or "none")
- Affected: …
- Risk: medium. One sentence why.

## Patterns
```text
1. <pattern>  ·  house pattern
   Where: <file:line>
   Evidence: 34 subscribers do the same, e.g. <file:line>, <file:line>
2. <pattern>  ·  against convention
   Where: <file:line>
   Evidence: <guideline or ADR quote + link>
   Shopware way: <how the codebase does it instead>
```

## Reuse
```text
1. <new symbol> duplicates <existing symbol>  ·  identical
   New: <file:line>
   Existing: <file:line>
```
(or "Nothing duplicated: <what was searched>")

## Quick-fix scale
Patch (3/5). <one sentence + quoted line>

## Stack
```text
1. <layer purpose>   <files>   reviewable alone
2. <layer purpose>   <files>   needs 1
```
(or "Keep as one PR: <reason>")

## Verdict
2–3 sentences: how well the change fits Shopware, and the one change that would improve it most.
````

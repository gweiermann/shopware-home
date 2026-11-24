---
name: judge-implementation
description: Judge how a Shopware PR or diff is built - its impact and risk, the patterns it uses and whether Shopware or the industry already knows them, what it duplicates instead of reusing, how much of a quick fix it is, whether its tests prove it, and whether it should be split into a PR stack. Use when asked to judge or rate an implementation or approach, "is this a hack?", "is this the Shopware way?", or "should this PR be split?".
---

# Judge implementation

A judgement of _how_ a change is built.
For bugs reproduced end to end, run `pr-review`.

Target: a PR number, a branch, or the local diff.
Get the full diff against its base (`gh pr diff <n>`, or `git diff <base>...<head>`) and read every changed file end to end, not just the hunks.

Every judgement carries its evidence: a quoted line and a link, or a search with its hit count.
A check that finds nothing stays out of the report; the report shows findings only.

## 1. Impact

Assess it the way `pr-review` step 6 does (`~/.agents/skills/pr-review/SKILL.md`): public API, breaking changes, affected, risk.
For what counts as public API and as breaking, apply `shopware-breaking-changes`, and `shopware-admin-public-api` for anything under `src/Administration`.

## 2. Pattern inventory

A **pattern** is a recurring solution shape the change relies on: an event subscriber, a decorator, a DAL entity extension, a message handler, a feature flag, a migration, a composable, a Pinia store, a mixin, a cache layer, a retry loop, a hand-rolled parser.
List every pattern the change introduces or newly applies, one line each, with the file:line where it lives.
The step is done when every new class, function, service definition, subscriber, store, and config key in the diff belongs to a listed pattern.

## 3. Judge each pattern

1. **Shopware**: does the codebase already solve this problem this way?
   Search `src/` for the same shape (`rg -l`), and name the hit count and two representative examples.
   Then check `coding-guidelines/`, `adr/`, and the nearest `AGENTS.md` for a rule that blesses, deprecates, or forbids it.
   A pattern Shopware has deprecated or replaced (a newer ADR, a `@deprecated` sibling) counts as against the convention, however many hits it still has.
2. **Industry**, only when Shopware does not use it: name the pattern and a primary reference (Symfony, Vue, Doctrine, PHP-FIG, MDN, a well-known book).
   A pattern known in the industry but against a Shopware rule (Doctrine ORM or QueryBuilder instead of the DAL, a decorator where an event fits) is worse than an unknown one: say so.
3. **Precedent**: the next contributors copy what they find.
   Would fifty copies of this pattern be good for the codebase?
   A questionable pattern in a place many people read (a core service, a base component, a much-copied module) weighs more than the same one in a corner.
4. **Verdict**: _house pattern_ (established in Shopware), _industry pattern_ (new to Shopware, known elsewhere), _against convention_, or _novel_ (neither: the reviewer has to learn it from this PR alone).

House patterns without a precedent concern collapse to one count line in the report.

## 4. Reuse

For every new function, method, helper, constant, type, and component in the diff, search for an existing one that does the same job: same name stem, same signature, same behaviour under another name.
Search the module first, then the bundle, then `src/` (Admin: also `src/app/service`, `src/core`, `src/app/composables`, and the Meteor `mt-*` components).
Classify each match: identical / same job, other edge cases / overlapping.
Also catch the reverse: an existing helper the change reuses although it does not quite fit, bent with extra flags or parameters.
Same for dependencies: a new composer or npm package needs a reason the installed ones do not cover; name the installed one that would.
The step is done when every new symbol and package has a match or a "no existing equivalent" from a search you ran.

## 5. Design checks

- **Layer**: each piece sits where its kind of logic belongs.
  Business rules in a controller, a Twig or Vue template, or a subscriber that only forwards; storefront or admin concerns in Core; DAL access in a Vue component instead of a repository or service.
- **Over-engineering and size**: every abstraction earns its place.
  An interface, factory, option, or extension point with a single user, flexibility nobody asked for, layers that only delegate.
  Then the size: set `git diff --stat` (tests and generated files apart) against the behaviour it delivers in one sentence.
  Acceptable when every added block serves that sentence; a finding when a meaningful share does not (name the blocks and their line count) or when the same behaviour fits in clearly less (sketch the smaller shape).
- **Consistency**: the PR solves each problem one way.
  The same kind of problem handled two ways inside the diff (two error-handling styles, two ways to load the same data, mixed Options and Composition API) is a finding.
- **Tests follow the neighbours**: new tests use the patterns of the tests already next to the code (test base classes, `TestDataCollection`, factories, `mount` helpers, fixtures).
  A test style that exists nowhere else in that folder is a finding; link the neighbour it should follow.

## 6. Quick-fix scale

Place the change on one rung and quote the line that decides it:

1. **Root-cause fix**: changes the place where the wrong behaviour originates; every caller benefits.
2. **Targeted fix**: right layer, but covers only the reported path; siblings with the same flaw stay (name them).
3. **Patch**: corrects the symptom downstream of the cause (a guard, a fallback, a re-sort, a `?? []`).
4. **Workaround**: routes around the flaw (a timeout, a retry, a duplicated code path, a special case for one entity or one extension).
5. **Hack**: depends on an accident of the current code (internal state, call order, a magic string, a CSS selector of another component).

Use `shopware-change-scope` to locate the root cause before you rate.

## 7. Tests go red without the change

Run `pr-review` step 3 (`~/.agents/skills/pr-review/SKILL.md`) in a worktree of the PR head, attached with `shopware-worktree-dev`.
Every test covering the new behaviour must go red on the base's code and green on the head.
Findings: a test that stays green without the change, a test that goes red only on a missing class or import, and new behaviour with no test at all.
When the change has no testable behaviour (style, snippet, docs) or the run is blocked, say which and why under "Anything else".

## 8. Stack split

Count the independent concerns in the change: patterns from step 2, plus refactors, renames, moved files, and test-only changes.
Propose a stack when two or more of them can each land green on their own:

- Order the layers so each one depends only on the layers below it.
- Typical cuts: preparatory refactor or rename → new extension point or service → the behaviour change → its call sites and cleanup.
- For each layer give its files, its one-line purpose, and whether it is reviewable alone (a reviewer can judge it without the next layer).

No split is a non-finding: leave the section out.

## 9. Anything else

Everything the steps above did not ask for but a reviewer should know: naming that fights the domain language, missing changelog or upgrade notes, a migration that is hard to back out, a security or performance smell, a comment that narrates the diff.
One line each, quoted and linked.

## 10. Report

Impact, quick-fix scale, and verdict always appear; every other section only with a finding.
Quote and link every claim.
Run it through the `humanizer` skill, when installed, before handing it over.

````markdown
## Impact and blast radius
- Public API: … (or "none")
- Breaking changes: … (or "none")
- Affected: …
- Risk: medium. One sentence why.

## Quick-fix scale
Patch (3/5). <one sentence + quoted line>

## Patterns
```text
1. <pattern>  ·  against convention
   Where: <file:line>
   Evidence: <guideline or ADR quote + link>
   Shopware way: <how the codebase does it instead>
2. <pattern>  ·  novel  ·  precedent risk
   Where: <file:line>
   Why copies hurt: <one sentence>
```
4 house patterns, no concerns: <names>.

## Reuse
```text
1. <new symbol> duplicates <existing symbol>  ·  identical
   New: <file:line>
   Existing: <file:line>
```

## Design
```text
1. <layer | size | consistency | test style>: <short title>
   Where: <file:line>
   <what and why, two lines at most>
```

## Tests without the change
```text
1. <test name> stays green on the base
   <file:line>
```

## Stack
```text
1. <layer purpose>   <files>   reviewable alone
2. <layer purpose>   <files>   needs 1
```

## Anything else
- <finding + link>

## Verdict
2–3 sentences: how well the change fits Shopware, and the one change that would improve it most.
````

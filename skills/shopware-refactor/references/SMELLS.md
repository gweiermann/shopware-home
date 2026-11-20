# Dead code, duplication, over-engineering

Load when working the second, third, or fourth bucket of the refactor plan.

## Dead code

Delete it. No `@deprecated`, no "keep it just in case" — git history is the
just-in-case. The only question is whether it is truly unreachable.

### Hunt

Run the static analysers first; they find the cheap cases for free.

```bash
composer phpstan
composer eslint:admin
```

Then sweep by hand for what analysers miss, always searching the **name as a
string** as well as the symbol:

| Candidate | How to confirm it is dead |
|---|---|
| `private`/`protected` method or property | `git grep -n 'methodName'` inside the class and its children; PHPStan flags unused privates |
| Class or service | `git grep -n 'ClassName'` over `*.php` **and** `*.xml` (DI service ids, arguments, tags) |
| Public method on an `@internal` class | Internal API has no outside consumers — no callers means dead |
| Public method on public API in `origin/trunk` | Not dead by definition. Leave it (see `shopware-breaking-changes`) |
| Event / subscriber | An event class with no dispatcher is dead; an event with no in-repo listener may be a public extension point — see §Over-engineering |
| Feature flag branch | Flag removed from `Feature` config or permanently on ⇒ delete the dead arm and the flag checks (`coding-guidelines/core/feature-flags.md`) |
| Snippet key | `git grep -n 'sw-product.list.messageLoadError'` over `*.twig`, `*.vue`, `*.ts`, `*.js`, `*.php`; keys are also built dynamically — grep the prefix too |
| Twig block or template | `git grep -n 'block name'` plus `{% sw_extends %}` / `{% sw_include %}` targets. **Admin `.html.twig` blocks are plugin override points** — a block with no in-repo user is still a contract; renaming or removing one silently breaks extensions. Treat it as public surface, not dead code |
| SCSS rule / variable | Grep the class name across `*.twig`, `*.vue`, `*.html.twig`; class names may be composed at runtime — check for the prefix |
| Admin component / override | `Component.register`, `Component.override`, `<sw-…>` tags in templates, route component maps |
| Export in a `.ts` module | Grep the identifier; also check `index.ts` barrels and `window.Shopware` registrations |

### Do not delete

Test-only helpers that real tests use, fixtures, migrations (never), and anything
whose only caller is a plugin-facing extension point.

## Duplication

Fix it once, in the nearest existing home.

1. **Find the existing home first.** A duplicated block usually belongs in a
   service, trait, helper, composable, or mixin that already exists. Adding a
   third abstraction next to two half-abstractions makes it worse.
2. **Two occurrences justify extraction only when they are the same *reason*.**
   Identical bodies that change for different reasons (a storefront rule and an
   admin rule that happen to agree today) are accidental duplication — leave them
   and note it.
3. **Do not parameterise the difference away.** If unifying two blocks needs a
   boolean flag or a mode string to select behaviour, they were two behaviours.
   Keep them apart.
4. **Duplication across layers is often correct.** A DTO that mirrors an entity,
   an Admin type that mirrors a PHP struct — these are boundaries, not copies.
5. **Copy-pasted tests count.** Collapse them with a data provider (PHP,
   `shopware-phpunit-tests`) or `it.each` (Jest) — but keep the test name
   descriptive per case.

## Over-engineering

The goal is the simplest shape that keeps every capability the code has today.
Simplification that removes capability needs approval — always.

### Catalogue

| Shape | Simpler form | Check before cutting |
|---|---|---|
| A check the platform already performs — ESLint rule, Vue compiler error, TypeScript, PHPStan, DAL validation | Delete it and let the tool report | See §Validation the platform already does |
| Interface with one implementation | Use the concrete class | Is it a plugin-facing seam? `@internal`? Is it type-hinted in a public constructor in `origin/trunk`? |
| Abstract base with one child | Merge into the child | Is it documented as the extension base for plugins? |
| Factory that constructs exactly one thing, unconditionally | `new` at the call site, or plain DI | Does the DI container or a decorator rely on the factory service id? |
| Strategy/registry with one entry | Inline the single strategy | Can plugins register more entries? |
| Config option nobody sets and nothing documents | Hard-code the default | Is it in `Resources/config/`, system config, or an env var operators may already have set? Then it is public — ask |
| Event nobody listens to | Removal candidate | Public event classes are extension surface; almost always keep |
| Wrapper DTO that only forwards | Pass the inner value | Is the wrapper part of a public signature in trunk? |
| Defensive null checks / `try` blocks for impossible states | Delete, or assert | Can the input really not be null? Prove it from the callers — all of them |
| Caching layer around something cheap | Direct call | Measure or reason from data before removing a cache |
| Generic "framework" written for one caller | Inline it into that caller | Is a second caller landing in the same stack? |
| Deep inheritance for shared helpers | Composition, or a plain function | — |

### Validation the platform already does

The most common over-engineering in build tooling, lint config, and validators:
a hand-written check for something ESLint, the Vue compiler, TypeScript, PHPStan,
or the DAL already rejects. It costs a code path, a spec, and an error message
that now has to stay consistent with the tool's.

Do not cut on suspicion — the tool has to be *at least as good*. Answer all four:

1. **Does it cover every form?** The usual reason a hand-rolled check survives is
   one shape the tool cannot see — a type-only `defineProps<Props>()`, a
   dynamically built key, a runtime-only value. If yours catches a form the tool
   misses, keep it and narrow it to that form.
2. **Does the author see it at the same point?** A lint rule that only fires in
   CI is not equivalent to a build error that fires on save. Equivalent timing,
   or say so when you propose the cut.
3. **Is the tool's message actionable?** A generic parser error where you had a
   sentence naming the fix is a real loss. Sometimes the answer is to keep the
   check purely for its message and drop the duplicate logic.
4. **Is the rule actually enabled here?** Grep `eslint.config.ts`, the PHPStan
   baseline, and `tsconfig.json` — a rule that is off or baselined is not
   coverage.

If all four hold, this is the one over-engineering cut worth proposing eagerly:
deleting it removes a divergence risk rather than a capability.

### Approval message

One message, all candidates, one round. Per candidate:

```
#N <what it is> — <path:line>
  Serves today: <evidence: callers, listeners, DI usages, extension surface>
  Proposal:     <the simpler shape>
  Lost if cut:  <capability that disappears, or "nothing — no callers, @internal">
```

Then ask for a decision per number. Rules:

- Evidence thin or the seam is plugin-reachable ⇒ recommend keeping, and say why.
- Never bundle a capability removal into an "obvious cleanup" commit.
- A no on one candidate does not block the other buckets — carry on with the
  SLAP, dead-code, and duplication cuts while waiting.

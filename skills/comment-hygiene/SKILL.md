---
name: comment-hygiene
description: Verify that code comments earn their place in the codebase. Use after adding or changing code comments, and during code review — scan the comments you or someone else added and remove AI slop (comments that answer a chat message, narrate the diff, restate scope decisions, or wall-of-text). A comment must make sense to a future reader who never saw this chat, this PR, or this diff.
license: MIT
---

# Comment Hygiene

Every comment you added must survive one test:

> **Does it still make sense to someone reading only the final code — no chat, no PR, no diff?**

If not, delete it. Run this pass on every changed file before you commit and on every diff you review.

## Delete these (AI slop)

| Pattern | Example | Why it's slop |
|---|---|---|
| **Answers a chat message** | `// As you asked, using a Map here` | The reader never saw the question. |
| **Narrates the diff** | `// Changed from forEach to for-of` / `// Now returns null instead` | Only means something next to the old code. That's what git blame is for. |
| **Doesn't parse without the diff** | `// This fixes it` / `// Moved this up` | Refers to a change, not to the code as it stands. |
| **Wall of comment** | 10-line block re-explaining the function below | Nobody reads it; it rots. Cut to one line or delete. |
| **Scope/deferral notes** | `// deliberately left out of scope for v1` / `// not touching this in this PR` | PR-lifecycle chatter. Belongs in the PR description, not the code. |
| **Restates the code** | `// increment i` above `i++` | Adds nothing. |
| **Example that repeats the call** | `@example const search = this.getFocusedSearch();` | Says nothing the name and doc text don't. Keep an `@example` only when it shows a non-obvious call shape, binding or result. |
| **TODO with no owner/context** | `// TODO: fix later` | Untracked and meaningless. Either link an issue or drop it. |

## Keep these (real documentation)

- **The non-obvious *why***: `// Stripe rounds half-up, so we match to avoid a 1-cent mismatch`
- **Warnings about consequences**: `// Order matters: auth must run before the tenant guard`
- **Contracts the type can't express**: `// Caller owns the returned handle and must close it`
- **Links to specs/tickets that explain a weird rule**: `// See NEXT-1234: legacy carts store price gross`

A good comment is **invariant** — it does not depend on the chat session, the PR, or the diff. It would be just as true if someone wrote the code fresh tomorrow.

## Edge cases

These live on the border. Prefer one line — most comments fit, and when they fit they should. It is not a hard cap: clarity wins over brevity, so a comment nobody can parse is worse than a two-line one that lands. If a one-liner turns cryptic, rewrite it plainer, don't just shorten it.

**Keep — but trim to the minimum:**

```php
// is null during CLI warmup
$context = $event->getContext();
```
```js
// computed would lose reactivity on the injected service
const service = inject('repositoryFactory');
```
```php
// runs inside the migration, before the DI container exists → repository not available
$connection->executeStatement(...);
```
```ts
// caveat: also rejections are cached
let transformPromise: Promise<Transform> | null = null;
```

Each states a timeless constraint in one line. No "keep this", no "do not extract", no "intentionally" — the fact alone earns the space.

**More rules for the keepers:**

- **State what to do, not what to avoid.** `// round per line, then sum` beats `// do not sum then round`. Prescribe the correct shape; the reader shouldn't have to invert a negative.
- **Don't explain known concepts.** A comment restating framework behaviour a competent reader already knows (`// nextTick waits for the DOM patch`, `// await resolves the promise`) is noise — delete it. Keep the explanation only when the behaviour is genuinely surprising in *this* spot.
- **The surprise bar is high.** Expected causal ordering ("indexer refreshes after the data changes"), obvious fallbacks, and anything a competent reader would assume anyway don't earn a line. A comment is for what would make a careful reader *pause*, not for what they'd nod at.
- **Prefer code over comment.** If the fact fits in a name, type, or method, encode it there and delete the comment — `setGrossPrice(...)` beats `setPrice(...) // price is gross`. Keep the comment only when you genuinely can't change the code (external API, generated code, a signature you don't own).
- **Never justify the comment inside the comment.** `// this is load-bearing:`, `// important!`, `// NOTE:` — if a line needs to argue for its own existence, it hasn't earned it. State the consequence instead: `// keep the whitespace intact (caused critical bugs before)`, not `// this indent is load-bearing`.
- **A tuned magic number's rationale is a legit keeper** — the *why can't* live in code: `// 0.7: tuned against the 2024 catalog, revisit if relevance drops`. It records the provenance a future reader needs before changing it.

**Delete — sounds like a why, but isn't:**

```php
// We keep the old method for backwards compatibility
public function getLegacyPrice(): float
```
Restates the name; no insight. (A removal date or ticket would flip it to keep.)

```js
// a bit hacky but it works for now, revisit later
el.style.marginTop = `${offset + 4}px`;
```
Timeless-sounding but empty — no why, no owner, no ticket. Vibes.

```php
// Refactored to reduce complexity and improve readability
private function resolve(Criteria $criteria): void
```
Describes the change's intent, not the code as it stands.

## The pass

1. List every comment added or changed in the diff.
2. For each, ask: *chat, diff, or PR artifact?* → delete. *Timeless why/warning/contract?* → keep.
3. When unsure, delete. A missing slop comment costs nothing; a lying or stale one costs trust.
4. Report what you removed and why, so the reviewer can see the reasoning.

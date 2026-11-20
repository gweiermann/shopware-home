# Detection Sweeps

Run from the repository root. Every sweep produces **candidates** — classify each one against `CATALOG.md` and verify it against the base before reporting.

```bash
git fetch origin trunk
BASE=$(git merge-base origin/trunk HEAD)
ADMIN=src/Administration/Resources/app/administration
```

For a GitHub PR, set the base from the PR instead:

```bash
BASE=$(git merge-base "origin/$(gh pr view <N> --json baseRefName -q .baseRefName)" HEAD)
```

---

## 1. Committed baselines — run this first

`src/meta/meta.spec.js` compares the live source against three **committed** baseline files. Regenerating a baseline makes the guard pass while the removal stays breaking, so the baselines' own diff is the highest-signal sweep in this file. Removed lines here are confirmed breaking changes.

```bash
git diff $BASE HEAD -- \
  $ADMIN/blocks-list.json \
  $ADMIN/src/meta/position-identifiers.json \
  $ADMIN/src/meta/data-sets.json \
  | grep -E '^-[^-]'
```

| File | Covers | Catalog |
|---|---|---|
| `blocks-list.json` | every `{% block %}` **and** `<sw-block name\|extends>` name | §1.1, §3.1 |
| `src/meta/position-identifiers.json` | `position-identifier="…"` app extension points | §7.1 |
| `src/meta/data-sets.json` | `publishData({ id })` app data sets | §7.2 |

If the PR removes a block **without** touching `blocks-list.json`, CI will fail on its own — still report it, the author may be about to "fix" it by regenerating.

Regenerate locally to compare when the baseline looks stale:

```bash
composer admin:generate-blocks-list
```

## 2. Twig blocks — removals, renames, moves

The baseline diff misses a block that merely **moved** to another file (§1.3). Compare per-file block sets:

```bash
for f in $(git diff $BASE HEAD --name-only -- "$ADMIN/**/*.html.twig"); do
  before=$(git show $BASE:$f 2>/dev/null | grep -oE '\{%\s*block\s+[^%[:space:]]+' | awk '{print $NF}' | sort -u)
  after=$([ -f $f ] && grep -oE '\{%\s*block\s+[^%[:space:]]+' $f | awk '{print $NF}' | sort -u)
  gone=$(comm -23 <(echo "$before") <(echo "$after"))
  [ -n "$gone" ] && printf '%s\n%s\n\n' "$f" "$gone"
done
```

For every name in `$gone`, check whether it survived elsewhere — if it did, it moved (§1.3), if not, it was removed (§1.1):

```bash
grep -rn "block <name>" $ADMIN/src --include="*.html.twig"
```

## 3. Template directives and conditional chains (§2)

**a. Every directive and `ref` that disappeared.** All of these are `breaking` per the compatibility sheet, not just the conditional ones:

```bash
git diff $BASE HEAD -- "$ADMIN/**/*.html.twig" \
  | grep -nE '^-.*\b(v-if|v-else-if|v-else|v-for|v-model|ref)="'
```

Pair each removal with the corresponding `+` line. A directive that moved to a different element is still a removal from the override's point of view.

**b. Repointed bindings** (§2.3) — a `:prop` whose expression changed feeds the child component something else:

```bash
git diff $BASE HEAD -- "$ADMIN/**/*.html.twig" | grep -nE '^[-+].*\s:[a-z-]+="'
```

**c. Blocks whose tail element changed.** For each block touched by the diff, read the base and the new version side by side and answer:

```bash
git show $BASE:<file> | sed -n '<start>,<end>p'
```

- Did the block's **last top-level element** carry `v-if` / `v-else-if` in the base, and no longer? → `breaking` (§2.1–2.4)
- Was a wrapper added around it, or another element appended after it? → `breaking` (§2.3, §2.4)
- Does any block **start** with `v-else` / `v-else-if`? Then the preceding sibling block's tail is a published contract too — check it changed neither.

Cross-check the neighbouring blocks even when only one of them appears in the diff.

## 4. Components

```bash
# removed or renamed registrations
git diff $BASE HEAD -- "$ADMIN/src" | grep -E "^-.*(Component\.(register|extend)|Module\.register)\("

# deleted component directories
git diff $BASE HEAD --diff-filter=D --name-only -- "$ADMIN/src" | grep -E '/(index|.*\.html)\.(ts|js|twig)$'

# newly privatised — verify each hit was public in the base
git diff $BASE HEAD -- "$ADMIN/src" | grep -E '^\+.*@private'
```

A component is public in the base when its `index.ts`/`index.js` has no `@private` annotation above the registration:

```bash
git show $BASE:$ADMIN/src/.../index.ts | head -20
```

## 5. Component API

```bash
# props, emits, slots, methods, computed, data
git diff $BASE HEAD -- "$ADMIN/src" \
  | grep -E "^-\s*(props|emits|methods|computed|watch|inject|mixins)\s*[:(]|^-.*\\\$emit\(|^-.*context\.emit\(|^-.*<slot\b"

# newly required props and narrowed types (§5.5, §5.6) — check both sides of each hit
git diff $BASE HEAD -- "$ADMIN/src" | grep -E '^\+.*required:\s*true'

# public → private moves in createExtendableSetup (§5.14)
git diff $BASE HEAD -- "$ADMIN/src" | grep -E '^[-+].*\b(public|private):\s*\{'

# typed extension surface (§5.15)
git diff $BASE HEAD -- "$ADMIN/src" | grep -E '^-.*ComponentPublicApiMapping' -A 10
```

For every component in the diff that other code overrides, diff the full API surface rather than trusting a grep:

```bash
diff <(git show $BASE:$ADMIN/src/.../index.ts) $ADMIN/src/.../index.ts
```

## 6. Snippets — skip

Snippet keys are **not** a breaking-change surface (`CATALOG.md` §6). There is nothing to sweep for. Do not report removed or renamed keys.

## 7. Extension SDK

Beyond the baseline files in §1, the published payload shape is unguarded (§7.3):

```bash
git diff $BASE HEAD -- "$ADMIN/src" | grep -E '^[-+].*(publishData|position-identifier|ui\.(componentSection|mainModule|menu))'
```

## 8. Services, stores, filters, directives, mixins, globals

```bash
git diff $BASE HEAD -- "$ADMIN/src" \
  | grep -E "^-.*(Shopware\.Service\(|Store\.register\(|Mixin\.register\(|Filter\.register\(|Directive\.register\()"

# global template helpers (§8.7) — callable from every template in every plugin
git diff $BASE HEAD -- "$ADMIN/src" | grep -E '^-.*globalProperties\.'
```

Then diff the service or store file whole — method signature changes (§8.2, §8.4) do not show up in a registration grep.

## 9. Routes, menu, ACL

```bash
git diff $BASE HEAD -- "$ADMIN/src" \
  | grep -E "^-\s*(name|path|parent|id):\s*['\"]"

# new required route params (§9.4) — a param without a trailing ? is required
git diff $BASE HEAD -- "$ADMIN/src" | grep -E "^\+\s*path:\s*['\"].*:[a-zA-Z]"

git diff $BASE HEAD -- "$ADMIN/src/**/acl/index.*"
```

Route and menu identifiers live in the module's `index.ts`; ACL privilege keys in `acl/index.*` plus `privileges` arrays on routes.

## 10. Asset files and imports (§10)

Deletions and renames of anything a plugin can reference by URL or import:

```bash
git diff $BASE HEAD --diff-filter=DR --name-status -- \
  "$ADMIN/static" \
  "$ADMIN/src/**/assets" \
  "$ADMIN/src/app/assets"
```

`--diff-filter=DR` catches renames too, which a plain `D` filter misses — and a rename is a deletion from the consumer's side (§10.2).

Format migrations hide behind an addition plus a deletion. Check whether each deleted image has a same-stem replacement, and whether the old path was routed through the deprecation list first (§10.3):

```bash
git diff $BASE HEAD --name-status -- "$ADMIN/static/img"
git diff $BASE HEAD -- "$ADMIN/build/vite-plugins/image-deprecation/deprecated-list.ts"
```

A deletion whose path never appeared in `deprecated-list.ts` skipped the deprecation cycle entirely.

An asset can also disappear without being deleted: drop the last import and the bundler stops emitting it (§10.3). Removed import lines with an asset extension are candidates:

```bash
git diff $BASE HEAD -- "$ADMIN/src" \
  | grep -E "^-.*(import|url\(|src=).*\.(png|jpe?g|webp|svg|gif|woff2?)"
```

SCSS partials and the symbols inside them (§10.5, §10.6) — these are build failures for plugins, not styling regressions:

```bash
git diff $BASE HEAD --diff-filter=DR --name-status -- "$ADMIN/src/app/assets/scss"
git diff $BASE HEAD -- "$ADMIN/src/app/assets/scss" | grep -E '^-\s*(\$[a-z-]+\s*:|@mixin|@function)'
```

Confirm reach before reporting a removed symbol — plugins import these through the `~scss/` alias:

```bash
grep -rn "<name>" $ADMIN/src --include="*.scss"
```

## 11. Styling (§11)

Three CSS things are `breaking`, not call-outs. Sweep for them specifically before looking at classes in general.

```bash
# functional state selectors (§11.2)
git diff $BASE HEAD -- "$ADMIN/src" | grep -E '^-.*is--[a-z0-9-]+'

# structural / functional properties (§11.3)
git diff $BASE HEAD -- "$ADMIN/src/**/*.scss" \
  | grep -E '^-\s*(display|position|visibility|z-index|pointer-events|overflow(-[xy])?|transform)\s*:'

# root selectors (§11.1) — the component's own top-level class
git diff $BASE HEAD -- "$ADMIN/src/**/*.scss" | grep -E '^-\s*\.(sw|mt)-[a-z0-9-]+\s*\{'
```

Everything else is a call-out (§12):

```bash
git diff $BASE HEAD -- "$ADMIN/src" | grep -E '^-.*class="' | head -50
```

Report only where a plugin or theme plausibly selects on the removed hook — do not list every class change.

## 12. Verification before reporting

For each surviving candidate:

```bash
git show $BASE:<path>          # did it exist, and was it public there?
grep -rn "<symbol>" $ADMIN/src # did it move rather than disappear?
```

Then name the concrete extension code that breaks. If you cannot write that snippet, the finding is not ready to report.

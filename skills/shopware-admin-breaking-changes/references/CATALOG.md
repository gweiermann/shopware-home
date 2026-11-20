# Breaking-Change Catalog — Administration

Every case assumes the symbol **exists and is public in the base branch**. If it does not, stop — it is `not-breaking`.

Verdicts: `breaking` · `partial` · `call-out` · `not-breaking`.

`partial` means the upstream compatibility sheet allows the change **only** under a stated condition. Outside that condition it is `breaking`.

The normative source is the [Shopware backward-compatibility guideline](https://developer.shopware.com/docs/resources/guidelines/code/backward-compatibility.html#administration). Rows marked *(sheet)* come straight from its Administration compatibility tables; the rest are cases this repository's extension mechanics add on top. Deprecation syntax for every fix lives in `DEPRECATION-PATTERNS.md`.

---

## 1. Twig blocks (`{% block %}` in `*.html.twig`)

Blocks are the primary override surface: `Shopware.Component.override(name, { template: '{% block x %}{% parent %}…{% endblock %}' })`. A missing or changed block fails **silently** — the override is dropped, no console error.

| # | Change | Verdict | Why |
|---|---|---|---|
| 1.1 | Block removed *(sheet)* | `breaking` | Overrides targeting it stop rendering |
| 1.2 | Block renamed *(sheet)* | `breaking` | Removal + addition; the old name is the contract |
| 1.3 | Block moved **within the same parent block** *(sheet)* | `partial` | Allowed only inside the same scope/parent block. Any move that changes the parent block or the file is `breaking` |
| 1.4 | Block moved to another component or file | `breaking` | The name survives the CI guard, but the override now runs in a different component's data scope — `this.x` / `$super` resolve differently or not at all |
| 1.5 | Block emptied but kept | `breaking` | `{% parent %}` renders nothing; overrides that appended to real content lose it |
| 1.6 | Block gains a wrapper element | `breaking` | Content injected after `{% parent %}` is now a sibling of the wrapper instead of the original element — layout, CSS and sibling-directive chains all shift |
| 1.7 | Child block moved out of its parent block | `breaking` | An override replacing the parent (no `{% parent %}`) previously removed the child too; nesting is part of the contract |
| 1.8 | Block content moved into `v-for` / a scoped slot | `breaking` | Variables an override referenced (`item`, slot props) are no longer in scope |
| 1.9 | Block's conditional chain changed | `breaking` | See §2 |
| 1.10 | Block name reused for unrelated content | `call-out` | Existing overrides still apply, but land in the wrong place with a wrong-looking result. Prefer a new name |
| 1.11 | `.html.twig` replaced by an SFC | `breaking` | Every Twig block in the file disappears at once |
| 1.12 | `{% block %}` converted to `<sw-block name>` under the same name | `breaking` | `blocks-list.json` accepts both, so CI passes — but Twig-template overrides do not resolve against the native block registry. Twig overrides silently stop applying |

**Fix:** never delete outright. Wrap the new markup in the old block, or keep the block with `{% deprecated %}` for one major (`DEPRECATION-PATTERNS.md` §1).

## 2. Template directives and the conditional-chain contract

The sheet is blunt here: **changing Vue template directives is not allowed** — neither the structural ones (`v-if`, `v-else-if`, `v-else`, `v-for`) nor the data-binding ones (`v-model`, `v-bind`/`:prop`).

| # | Change | Verdict | Why |
|---|---|---|---|
| 2.1 | `v-if` / `v-else-if` / `v-else` added, removed or moved *(sheet)* | `breaking` | Overrides bind to the element's conditional identity, and chains cross block boundaries |
| 2.2 | `v-model` target changed or removed *(sheet)* | `breaking` | An override that re-binds the same model writes to a property nobody reads any more |
| 2.3 | `v-bind` / `:prop` binding removed or repointed *(sheet)* | `breaking` | The child component silently loses its input |
| 2.4 | `ref="…"` renamed or removed *(sheet)* | `breaking` | Overrides reach elements and child components through `this.$refs.<name>` |
| 2.5 | `v-for` iteration variable renamed | `breaking` | Every override inside the loop references the old name |
| 2.6 | A new Vue feature is adopted whose semantics change existing rendering *(sheet)* | `breaking` | The sheet forbids new framework functionality with breaking behaviour |
| 2.7 | Condition expression changed but the chain kept | `call-out` | Overrides still compile; the branch they extend may now trigger at different times |

### The chain across block boundaries

A block that ends on an element carrying `v-if` / `v-else-if` publishes a **continuable condition chain**. Extensions rely on it:

```twig
{% block sw_tree_item_element_leaf_icon %}
{% parent %}
<div v-else class="my-plugin-leaf">…</div>
{% endblock %}
```

Core itself does this — `sw-tree-item.html.twig:20-30`:

```twig
{% block sw_tree_item_element_leaf_icon %}
<div v-if="item.childCount <= 0" class="sw-tree-item__leaf"></div>
{% endblock %}

{% block sw_tree_item_element_toggle %}
<div v-else class="sw-tree-item__toggle" …>
```

This is not folklore — core ships runtime machinery to keep the chain working across the new block system (`$swLegacyBlockIf` / `$swLegacyBlockElseIf` / `$swLegacyBlockElse` in `src/app/adapter/view/vue.adapter.ts`, backed by `sw-block-override/shim/legacy-condition-context.ts`). The chain is a supported contract.

Breaks, all `breaking`, when a block whose last element carried `v-if`/`v-else-if`:

- loses the directive,
- has that element removed or made unconditional,
- has it wrapped so it is no longer the last **top-level** node,
- gains another element appended after it.

Symmetrically, a block that **starts** with `v-else` depends on the previous sibling block — changing that block's tail is the same break.

The failure is loud: Vue throws `v-else/v-else-if has no adjacent v-if` and the whole component fails to render, not just the extension.

### Fixes, in order of preference

**a. Restore the chain.** Keep a `v-if`-carrying element as the last top-level node of the block.

**b. Re-open the chain with an empty template.** When the conditional element genuinely has to go:

```twig
{% block sw_tree_item_element_leaf_icon %}
{# @deprecated tag:v6.9.0 - Only kept so extensions can continue the v-if chain with {% parent %}<x v-else> #}
<template v-if="item.childCount <= 0">
    <!-- keep this comment: an empty template is dropped and would break the chain -->
</template>
{% endblock %}
```

**c. Break it deliberately** — only with an `UPGRADE-6.8.md` entry naming the block and the replacement pattern.

## 3. Native blocks (`<sw-block>`, 6.8+)

| # | Change | Verdict | Why |
|---|---|---|---|
| 3.1 | `<sw-block name>` removed or renamed | `breaking` | `<sw-block extends="…">` overrides register into a name nobody reads |
| 3.2 | `:data="$dataScope"` removed from a block | `breaking` | Overrides using `#default="{ product, formatPrice }"` receive nothing |
| 3.3 | A key removed from the exposed scope | `breaking` | The same destructuring breaks |
| 3.4 | Block moved inside `v-for` | `breaking` | Each iteration registers an override entry; content renders N times |
| 3.5 | Block moved between a `v-if` and its `v-else` sibling | `breaking` | Inserts a node into the chain and breaks Vue's conditional pairing |
| 3.6 | Block moved between `<template #slot>` and its parent component | `breaking` | Disrupts slot composition |
| 3.7 | Nesting changed so `<sw-block-parent />` resolves to a different chain link | `breaking` | Parent resolution walks registry order |

## 4. Components

| # | Change | Verdict | Why |
|---|---|---|---|
| 4.1 | Base component removed or renamed *(sheet)* | `breaking` | Templates, `Component.extend`, `Component.override` and direct usage all fail |
| 4.2 | Module component removed or renamed *(sheet)* | `breaking` | Same |
| 4.3 | Public component annotated `@private` | `breaking` | Declares the extension contract withdrawn even though the code still runs |
| 4.4 | Component becomes a thin wrapper around an `mt-*` Meteor component | `breaking` | Inner blocks, props, emits and CSS hooks of the old implementation are gone |
| 4.5 | Component's `template` import repointed to another file | `breaking` | Its whole block set changes |
| 4.6 | `Component.extend` parent changed | `breaking` | Inherited blocks and API shift under existing overrides |
| 4.7 | Component usage removed from a template | `call-out` | The component still exists, but blocks inside it no longer render on that page |

**Fix:** register the replacement, keep the old name with `@deprecated tag:` + `@status deprecated` + the `deprecated` component option (`DEPRECATION-PATTERNS.md` §3).

## 5. Component API

Reachable from Options overrides (`this.x`, `this.$super('x')`) and Composition overrides (`previousState.x`).

| # | Change | Verdict | Notes |
|---|---|---|---|
| 5.1 | Method removed or renamed *(sheet)* | `breaking` | Keep the old name delegating to the new one |
| 5.2 | Method return value changed *(sheet)* | `breaking` | Add a new method instead of changing the old one |
| 5.3 | Method parameters changed *(sheet)* | `partial` | Allowed only for a **new optional parameter with a default**, or when the method already takes a single destructured object |
| 5.4 | Required prop removed or renamed *(sheet)* | `breaking` | |
| 5.5 | A **new required** prop added *(sheet)* | `breaking` | Add it optional and warn when it is empty (`DEPRECATION-PATTERNS.md` §6) |
| 5.6 | Existing prop becomes required, or its type narrows | `breaking` | Same remedy |
| 5.7 | Prop default changed | `call-out` | `breaking` when the rendered result changes for existing callers |
| 5.8 | Vue event removed or renamed *(sheet)* | `breaking` | Annotate and offer the alternative in the deprecation comment |
| 5.9 | Vue event parameters changed *(sheet)* | `partial` | Allowed only for a **new optional parameter with a default**, and only when the payload is already an object consumed by destructuring |
| 5.10 | Slot removed or renamed *(sheet)* | `breaking` | Keep both slots for one major (`DEPRECATION-PATTERNS.md` §2) |
| 5.11 | Scoped-slot payload key removed | `breaking` | |
| 5.12 | `computed` entry removed or renamed | `breaking` | `$super('name')` and `previousState.name` break |
| 5.13 | `data()` key removed or renamed | `breaking` | Options overrides read `this.key` |
| 5.14 | Method turned from sync to async | `breaking` | `$super` callers do not await |
| 5.15 | `inject`ed key no longer provided | `breaking` | |
| 5.16 | Mixin removed from a component | `breaking` | The mixin's API disappears from `this` |
| 5.17 | A key moves from `public` to `private` in `createExtendableSetup` | `breaking` | It drops out of `previousState` top level into `previousState._private` |
| 5.18 | `ComponentPublicApiMapping` entry removed or reshaped | `breaking` | Typed overrides stop compiling |
| 5.19 | Options API → Composition API migration | `call-out` | The shim covers most overrides but logs a deprecation. `breaking` when the override needs `provide`, `components`, `directives`, `emits`, a custom `render()`, or a dot-notation `watch` — all silently dropped by the shim |

## 6. Snippets — explicitly not a breaking-change surface

**Snippet keys are out of scope.** Removing, renaming or re-namespacing a snippet key is **not** a breaking change in the Administration, and neither is changing a value's placeholders or pluralisation branches. Do not report any of it, and do not write an `UPGRADE` entry for it.

Fix the German counterpart when you touch `en.json` — `composer translation:lint` — but that is a completeness check, not a compatibility one.

## 7. Extension SDK / apps (out-of-process)

| # | Change | Verdict | Why |
|---|---|---|---|
| 7.1 | `position-identifier="…"` removed or renamed | `breaking` | `ui.componentSection.add` targets a dead location; the app's UI disappears |
| 7.2 | Published data set removed or renamed (`publishData({ id })`) | `breaking` | `data.get` / `data.subscribe` resolve to nothing |
| 7.3 | Published entity shape narrowed | `breaking` | Not covered by any guard — apps read the payload directly |
| 7.4 | Action button, main module or menu location id changed | `breaking` | The app's registration no longer matches |
| 7.5 | A required app privilege added to an existing surface | `breaking` | Installed apps lack the privilege until re-approved |

## 8. Global object, services, stores

The sheet forbids changing the public API of the global `Shopware` object and of state stores outright.

| # | Change | Verdict |
|---|---|---|
| 8.1 | Anything on the `Shopware` global removed or renamed *(sheet)* | `breaking` |
| 8.2 | Service removed or renamed (`Shopware.Service('x')`) | `breaking` |
| 8.3 | Service method removed, renamed, or signature changed | `breaking` — extensions decorate services and call through |
| 8.4 | Store removed or renamed (`Shopware.Store.get('x')`) *(sheet)* | `breaking` |
| 8.5 | Store state key, getter or action removed or renamed *(sheet)* | `breaking` |
| 8.6 | Filter, directive or mixin removed or renamed | `breaking` |
| 8.7 | A globally available template helper removed or renamed *(sheet)* | `breaking` — `$t`, `$tc`, `$sanitize`, `$createTitle` and friends are callable from every template, core and plugin alike |
| 8.8 | An API service's request path, payload or response shape changed | `breaking` |

## 9. Modules, routes, ACL

| # | Change | Verdict | Why |
|---|---|---|---|
| 9.1 | Module removed or renamed (`Shopware.Module.register`) | `breaking` | |
| 9.2 | Route of a module removed or renamed *(sheet)* | `breaking` | `$router.push({ name: 'sw.product.detail' })` in extensions |
| 9.3 | Route parameters changed *(sheet)* | `breaking` | Deep links and app redirects |
| 9.4 | A **new required** route parameter added *(sheet)* | `breaking` | Add it optional with the previous behaviour as default |
| 9.5 | Menu entry `id` or `parent` changed | `breaking` | Plugin entries parented to it vanish from navigation |
| 9.6 | ACL privilege key removed or renamed | `breaking` | Plugin `acl` additions and `acl.can()` checks silently return false |
| 9.7 | A new privilege required for an existing route or action | `breaking` | Existing roles lose access — needs a migration for existing roles |

## 10. Assets and imports

Assets are a public surface. Plugins reference them by URL (`/administration/static/img/…`), by `src/` import, and SCSS partials by the `~scss/` alias. The sheet forbids **renaming, removing, or no longer using** an asset — the last one matters, because an asset core stops importing can drop out of the build and take the URL with it.

| # | Change | Verdict | Why |
|---|---|---|---|
| 10.1 | File under `static/` deleted or renamed *(sheet)* | `breaking` | The URL 404s for every plugin and app that referenced it |
| 10.2 | Asset moved to another directory | `breaking` | Identical to deletion from the consumer's side |
| 10.3 | Core stops importing an asset *(sheet)* | `breaking` | Bundled assets are emitted because something imports them; drop the import and the file leaves the build output |
| 10.4 | Format migration (`.png` → `.webp`) with the old file dropped | `breaking` | The new file does not answer the old URL |
| 10.5 | Component-local `assets/` file deleted (`src/module/**/assets/*`) | `breaking` | Reachable through the `src/` alias |
| 10.6 | SCSS partial under `src/app/assets/scss/` removed or renamed | `breaking` | `@import '~scss/variables'` in plugin SCSS fails the build |
| 10.7 | SCSS variable, mixin or function removed from those partials | `breaking` | A build error, not a styling regression |
| 10.8 | File under `static/fixtures/` deleted | `call-out` | Demo and test data; flag it, no entry unless something outside tests reads it |
| 10.9 | Asset content replaced, filename unchanged | `not-breaking` | The reference still resolves |

### The established deprecation path

Images are deprecated before removal. `build/vite-plugins/image-deprecation/` warns at build time for every path listed in its `deprecated-list.ts`:

```
DEPRECATION: In file "…", the image import "…" uses a deprecated format.
PNG and JPG assets have been migrated to WebP. Please update your assets to WebP…
```

So the correct sequence is: add the replacement, keep the old file, add its path to `deprecated-list.ts`, and remove it only in the next major with an `UPGRADE` entry. A PR that skips to deletion is `breaking` — say so and point at the list.

## 11. Styling

Not all CSS is cosmetic. The sheet draws a hard line between decorative properties and the ones that carry structure or behaviour.

| # | Change | Verdict | Why |
|---|---|---|---|
| 11.1 | Root CSS selector of a component renamed or removed *(sheet)* | `breaking` | `.sw-card` and friends are the anchor every plugin stylesheet hangs off |
| 11.2 | Functional selector renamed or removed — `is--active`, `is--disabled`, `is--*` *(sheet)* | `breaking` | These are state API, not decoration; plugins both read and set them |
| 11.3 | Structural or functional CSS property removed or changed — `display`, `position`, `visibility`, `z-index`, `pointer-events`, `overflow`, `transform` *(sheet)* | `breaking` | Layout and interaction behaviour of the extended element changes |
| 11.4 | Purely visual property changed — colour, spacing, font, shadow *(sheet)* | `partial` | Allowed. Only visual properties may be renamed or removed |
| 11.5 | Non-root, non-functional class renamed | `call-out` | Plugin selectors stop matching, but the class was never contract |

## 12. Call-outs that are not contracts

Report these as `call-out` with the concrete consequence, never as `breaking`.

| # | Change | Consequence |
|---|---|---|
| 12.1 | Descendant class renamed or removed (§11.5) | Plugin and theme SCSS selectors stop matching |
| 12.2 | DOM nesting or element order changed | Descendant/sibling selectors and E2E locators break |
| 12.3 | Element type changed (`<div>` → `<span>`, `<button>` → `<mt-button>`) | Selectors and styling reset |
| 12.4 | `data-*` / `id` hook removed | Test suites and integrations lose their anchor |
| 12.5 | Block kept but repurposed (§1.10) | Overrides render in a wrong-but-valid place |

Root selectors, `is--*` selectors, structural CSS properties and SCSS symbols are **not** in this table — those are `breaking` (§11.1–11.3, §10.7).

## 13. Never report

- Symbol absent from the base branch — including API introduced by an earlier PR in the same stack.
- `@private`, `@internal`, or `@experimental` symbols, and anything behind a not-yet-released feature flag.
- `*.spec.*`, `.spec/`, `test/`, `_fixtures/`.
- Generated files, unless the generated file **is** the baseline (see `DETECTION.md` §1).
- Behaviour that was a bug. Fixing it is a fix — mention it in the PR description if consumers could reasonably have depended on it.

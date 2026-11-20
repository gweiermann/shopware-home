# Writing the `UPGRADE-6.8.md` Entry

Every `breaking` finding needs one. No entry means the change ships undocumented — report that as a finding in its own right.

## Where

`UPGRADE-6.8.md` → `# Administration` → inside the `<details>` block that follows it. Add a `## <Heading>` section, or extend an existing one when the same surface already has a section (block removals, for example, are collected under one heading with a `####` sub-heading per file).

Keep a blank line before and after every heading and between paragraphs.

## Voice

Write for an extension developer reading this **after** upgrading, with no access to this PR or its discussion.

- **Past tense, as if the removal already happened** — "The block `x` has been removed", never "will be removed" or "we are removing".
- State the change, who is affected, and what to do. Not the reasoning, the internals, or the history.
- Name the concrete before and after. One copy-pasteable snippet beats a paragraph.
- Full paths from the repository root for files; backticked identifiers for blocks, components, props, snippet keys.
- No "we", no PR references, no rejected alternatives.

## Templates

### Removed blocks

Collect several removals under one heading, grouped by file:

```markdown
## Removed Administration Twig blocks from `sw-product-detail`

The following blocks have been removed. Use the respective replacements instead:

#### sw-product-detail.html.twig

* `sw_product_detail_content_tabs` -> `sw_product_detail_tabs_content`
```

Without a replacement, say so and give the new extension point:

```markdown
The block `sw_product_detail_content_tabs` has been removed. The tab list is now rendered by `mt-tabs`; add custom tabs through the `tabItems` prop of `sw-product-detail` instead of extending the removed block.
```

### Changed conditional chain

```markdown
## `sw_tree_item_element_leaf_icon` no longer opens a conditional chain

The block `sw_tree_item_element_leaf_icon` in `src/Administration/Resources/app/administration/src/app/component/tree/sw-tree-item/sw-tree-item.html.twig` no longer ends on an element with `v-if`. Overrides that continued the chain now fail to compile:

### Before

    {% block sw_tree_item_element_leaf_icon %}
    {% parent %}
    <div v-else class="my-leaf">…</div>
    {% endblock %}

### After

    {% block sw_tree_item_element_leaf_icon %}
    {% parent %}
    <div v-if="item.childCount > 0" class="my-leaf">…</div>
    {% endblock %}
```

### Removed or privatised component

```markdown
## `sw-card-filter` is internal

`sw-card-filter` has been marked `@private` and is no longer part of the public component API. Use `mt-card` with the `filter` slot instead. Existing `Shopware.Component.override('sw-card-filter', …)` calls keep running but are no longer supported and can break in any minor release.
```

### Changed component API

```markdown
## `sw-product-list` column API

The `columns` computed property of `sw-product-list` has been renamed to `dataColumns` and now returns `Ref<Column[]>`.

### Before

    Shopware.Component.override('sw-product-list', {
        computed: {
            columns() {
                return [...this.$super('columns'), myColumn];
            },
        },
    });

### After

    Shopware.Component.overrideComponentSetup()('sw-product-list', (previousState) => ({
        dataColumns: computed(() => [...previousState.dataColumns.value, myColumn]),
    }));
```

### Removed extension SDK surface

```markdown
## Removed Administration position identifiers

The position identifier `sw-product-detail-base__custom` has been removed. Apps registering a component section there no longer render. Use `sw-product-detail-base__properties` instead.
```

## Checklist before you call the entry done

- [ ] Under `# Administration`, inside the `<details>` block.
- [ ] Past tense throughout.
- [ ] Names the exact identifier and the full file path.
- [ ] Gives a replacement, or states explicitly that there is none.
- [ ] Before/after snippet for anything an extension author has to rewrite.
- [ ] No reference to this PR, this branch, or the discussion around it.

## Related

- `shopware-release-docs` — whether the change also needs a `RELEASE_INFO-6.<minor>.md` entry (it does when extension authors benefit from knowing early, not only at the major).
- A `changelog/_unreleased/` entry is a separate, always-required artifact — the upgrade entry does not replace it.

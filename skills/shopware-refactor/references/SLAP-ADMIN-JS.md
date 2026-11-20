# SLAP — Administration JS/TS/Vue

Worked examples for `src/Administration/Resources/app/administration`. Load when
splitting a component, deciding where an extracted piece belongs, or judging
whether a `computed` has grown a second altitude. For PHP see
[`SLAP-PHP.md`](SLAP-PHP.md).

Admin components are **not SFCs** — they are component-factory configs
(`Shopware.Component.wrapComponentConfig`) with the template in a sibling
`.html.twig`. That shapes every rule below: the Vue options order is fixed, so
step-down applies *inside* `methods`, and the template is a separate altitude of
its own.

## Where an extracted piece belongs

Climb this ladder only as far as the first rung that fits. Every rung up costs a
reader one more file to open, and rungs 3+ are extension surface.

| Rung | Home | Use when |
|---|---|---|
| 1 | `computed` in the same component | Derived from component state, no arguments, no side effects |
| 2 | `methods` in the same component | Needs arguments, or performs an action; still component-specific |
| 3 | Module-local component / view split (`sw-…/component/`, `sw-…/view/`) | The chunk owns markup *and* behaviour |
| 4 | Composable in `src/app/composables/use-*.ts` | Reactive logic reused by two or more components |
| 5 | Module service (`sw-…/service/*.ts`) registered in the DI container | Stateless domain logic, or API orchestration, no Vue reactivity |
| 6 | `src/core/service/` | Framework-level, Vue-independent, used across modules |
| 7 | Pinia store (`src/app/store/`) | State genuinely shared between unrelated components |

Two rules that stop the ladder being abused: a Pinia store is not a dumping
ground for one component's state, and a composable that only ever has one caller
is rung 1 or 2 wearing a costume.

## Example 1 — one method doing four jobs

Tells: nesting past two levels, `and` in the name, notification handling
(presentation policy) tangled with `Criteria` assembly (mechanism).

**Before**

```ts
methods: {
    async loadAndApplyFilters(): Promise<void> {
        this.isLoading = true;

        try {
            const criteria = new Criteria(this.page, this.limit);
            if (this.term) {
                criteria.setTerm(this.term);
            }
            if (this.activeOnly) {
                criteria.addFilter(Criteria.equals('active', true));
                if (this.salesChannelId) {
                    criteria.addFilter(Criteria.equals('salesChannels.id', this.salesChannelId));
                }
            }
            criteria.addAssociation('manufacturer');

            const result = await this.productRepository.search(criteria, Shopware.Context.api);
            this.products = result;
            this.total = result.total ?? 0;
        } catch (error) {
            this.createNotificationError({
                message: this.$t('sw-product.list.messageLoadError'),
            });
        } finally {
            this.isLoading = false;
        }
    },
},
```

**After** — `criteria` moves to a `computed`, which is the Admin convention for
list pages and makes it assertable in Jest without a repository mock at all.
`getList()` is left as policy: fetch, publish, report.

```ts
computed: {
    productRepository(): Repository<'product'> {
        return this.repositoryFactory.create('product');
    },

    criteria(): Criteria {
        const criteria = new Criteria(this.page, this.limit);
        criteria.addAssociation('manufacturer');

        if (this.term) {
            criteria.setTerm(this.term);
        }

        if (!this.activeOnly) {
            return criteria;
        }

        criteria.addFilter(Criteria.equals('active', true));

        if (this.salesChannelId) {
            criteria.addFilter(Criteria.equals('salesChannels.id', this.salesChannelId));
        }

        return criteria;
    },
},

methods: {
    async getList(): Promise<void> {
        this.isLoading = true;

        try {
            this.products = await this.productRepository.search(this.criteria, Shopware.Context.api);
            this.total = this.products.total ?? 0;
        } catch {
            this.createNotificationError({
                message: this.$t('sw-product.list.messageLoadError'),
            });
        } finally {
            this.isLoading = false;
        }
    },
},
```

What did *not* happen: no composable, no new service. Rung 1 was enough.

## Example 2 — rule 2, "never reach up" (the most common Admin violation)

A service, composable, or repository helper that notifies, translates, or
navigates has taken the component's job. It can no longer be called from a
background path, and its Jest test needs the notification mixin, `$t`, and a
router.

```ts
// ❌ Reaching up — a data function that owns presentation policy.
export async function saveProduct(product: Entity<'product'>): Promise<void> {
    try {
        await repository.save(product, Shopware.Context.api);
        Shopware.Service('notificationService')?.createNotification({ variant: 'success', message: 'Saved' });
        Shopware.Application.view?.router?.push({ name: 'sw.product.index' });
    } catch (error) {
        Shopware.Service('notificationService')?.createNotification({ variant: 'error', message: 'Failed' });
    }
}
```

```ts
// ✅ The helper does one thing and lets the failure surface.
export async function saveProduct(product: Entity<'product'>): Promise<void> {
    await repository.save(product, Shopware.Context.api);
}

// The component decides what a failure means to a user, and where to go next.
methods: {
    async onSave(): Promise<void> {
        try {
            await saveProduct(this.product);
            await this.reloadProduct();
            this.createNotificationSuccess({ message: this.$t('sw-product.detail.messageSaveSuccess') });
        } catch {
            this.createNotificationError({ message: this.$t('sw-product.detail.messageSaveError') });
        }
    },
},
```

Admin variants of reaching up, all worth cutting: a composable that calls
`createNotificationError`; a service that reads `acl` to decide business rules
instead of the component gating the action; a child component that mutates a prop
instead of emitting; a store action that pushes a route; a service that reads
`this.$route` state.

## Example 3 — the template is its own altitude

Business logic in `.html.twig` is invisible to Jest, untypeable, and unnamed —
it is an unnamed method living in markup (`src/module/AGENTS.md` lists it as an
anti-pattern).

```twig
{# ❌ A policy decision, spelled out as an expression #}
<sw-button
    :disabled="!acl.can('product.editor') || isLoading || (!product.active && !allowInactiveEditing)"
    @click="onSave"
>
```

```twig
{# ✅ #}
<sw-button :disabled="isSaveDisabled" @click="onSave">
```

```ts
computed: {
    isSaveDisabled(): boolean {
        if (!this.acl.can('product.editor') || this.isLoading) {
            return true;
        }

        return !this.product.active && !this.allowInactiveEditing;
    },
},
```

Rule of thumb for a template expression: a property access, a single negation, or
a method call is fine. Two operators combining different concepts is a `computed`
that hasn't been named yet.

## Example 4 — rule 3, extraction that does not earn its name

```ts
// Before: one clear map.
const labels = this.products.map((product) => product.translated.name);

// "After": the name restates the body. The reader gains a file jump and loses
// the information they already had.
const labels = this.mapItems(this.products);
```

`productNames` as a `computed` earns it. `mapItems()` does not. Same test as in
PHP: the name must replace a *how* with a *what*.

## Example 5 — splitting a page that got fat

When a component config passes a few hundred lines, the split is usually along
altitudes, not along line count:

1. **Down to the template layer** — a coherent block of markup plus its own state
   becomes a module component (rung 3). It gets props in, emits out, and owns no
   loading logic.
2. **Sideways into views** — detail-page tabs belong in `view/`, one per route
   child, each owning its own section of the entity.
3. **Out to a service** — API orchestration with no reactivity (rung 5).
4. **Nothing** — a config that is long because it has twenty simple `computed`
   properties is fine. Length is a tell, not a verdict.

Keep the `created()` → `createdComponent()` convention: the lifecycle hook stays
a one-liner and `createdComponent()` is the narrated list of startup steps.

## Step-down order (rule 4)

The Vue options order is fixed by convention — `template`, `inject`, `mixins`,
`props`, `emits`, `data()`, `computed`, lifecycle hooks, `methods`. Apply
step-down *within* the blocks:

- `computed`: injected repositories and services first, then derived state, then
  the derived-from-derived properties.
- `methods`: `createdComponent()` first, then event handlers (`onSave`,
  `onDelete`) in the order a user hits them, then the helpers each handler calls,
  then shared leaves.

A reader who reads only `createdComponent()` and the `on…` handlers must come
away with a true summary of what the component does.

## Admin tells worth naming

| Tell | Cut |
|---|---|
| `computed` that awaits, fetches, or mutates state | It is a method (or a watcher); `computed` is derivation only |
| `Criteria` built inside a `methods` fetch | Move to a `criteria` computed — free unit testability |
| `this.$t(...)` inside a service or composable | Return a key or throw; let the component translate |
| A watcher that re-implements what a `computed` would derive | Delete the watcher |
| A Jest test that needs four mocks to reach one branch | The branch is mixed with mechanism it should not own |
| `data()` holding something derivable from props or state | `computed` |
| `async` handler with a `.then()` chain inside | One `await` per step, guard clauses first |
| A prop named `mode`, `type`, or a boolean that switches behaviour | Two components, or two methods |
| Deeply chained optional access in the template (`a?.b?.c?.d`) | Name it in a `computed` |

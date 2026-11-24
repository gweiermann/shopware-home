# shopware/shopware instances

Platform hosts everything an agent runs (Administration, Storefront, the API, the database), so it gets several checkouts instead of one.
Each `shopware-<n>` is an **instance**: a full checkout on `trunk` with its own Docker stack at `http://shopware-<n>.orb.local`.

- Create one with `bin/setup-shopware-instance.sh --name shopware-<n> --index <n + 2>`; the index offsets its host ports by `index * 100`.
  Three at most unless the user's preferences say otherwise; the `shopware-local-dev` skill says when to add one.
- Feature work happens in worktrees inside an instance, `shopware-<n>/.claude/worktrees/<name>`, so the instance's container already sees them.
  The `shopware-worktree-dev` skill attaches a worktree to its instance.
- The instance checkout itself stays on `trunk`.

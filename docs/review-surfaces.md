# Review surfaces in Shopware

What the generic `user-review` skill needs to know about Shopware: personas, surface kinds, and how to run two versions side by side.

## Personas

- Merchant with full rights in the Administration.
- Restricted admin user (ACL role without some privileges).
- Shop customer, logged in, in the Storefront.
- Guest in the Storefront.
- Integrator calling the Admin API or Store API (ERP sync, headless frontend), including the bulk path `_action/sync`.
- Operator running `bin/console`, deploying, setting env vars and config.
- Developer running the repo's scripts (`composer` / `npm` scripts, `bin/*.sh`, tooling under `.github` or `src/**/Resources/app/**/scripts`).
- Extension developer writing an app `manifest.xml`, a plugin `config.xml`, or a `theme.json`.

## Footprint specifics

Every changed snippet key in `en.json` / `de.json` (Administration) or `storefront.en.json` / `storefront.de.json` (Storefront) is a label someone reads, so it is footprint.
German Administration snippets use "Du", Storefront snippets use "Sie".
Changed exception messages, validation messages and `bin/console` output strings are footprint too.
Public PHP and JS symbols belong to the code review and the `shopware-breaking-changes` skill.

## Two running versions

Create both worktrees inside an instance checkout, so its container mounts them, and attach each with the `shopware-worktree-dev` skill's `attach.sh`:

```bash
I=<instance checkout>
git -C $I fetch origin trunk pull/<n>/head:pr-<n>
git -C $I worktree add .claude/worktrees/user-review-<n>-after pr-<n>
git -C $I worktree add --detach .claude/worktrees/user-review-<n>-before "$(git -C $I merge-base origin/trunk pr-<n>)"
```

| Footprint contains | Each version needs |
|---|---|
| Administration screens only | its own admin dev server (`attach.sh` prints it); `/api` may stay on the instance |
| PHP, entity schema, API responses, Storefront templates, console commands, config | a backend that runs that worktree's PHP, once per version on its own port: follow [run-a-pr.md](run-a-pr.md) |
| scripts and tooling only | the attached worktree; run the script from it |

## Reaching each surface

### Screens (Administration, Storefront)

Drive them with the Playwright browser tools on the `localhost` URLs `attach.sh` prints; browser agents may only type the test login on `localhost`.
For feature flags, ACL forcing, demo data, and screenshot tricks, see the `pr-review-report` skill's `references/live-verification.md` where installed.

### Admin API and Store API

The integrator starts at the API reference: `/api/_info/stoplightelements.html` or `/store-api/_info/stoplightelements.html` on each version.

```bash
# Admin API: an integration's client credentials (Settings → System → Integrations), or the admin user for a quick probe
curl -s -X POST "$APP_URL/api/oauth/token" -H 'Content-Type: application/json' \
  -d '{"grant_type":"client_credentials","client_id":"<id>","client_secret":"<secret>"}'

# Store API: the sales channel's access key
curl -s "$APP_URL/store-api/<route>" -H 'sw-access-key: <key>' -H 'Accept: application/json'
```

Errors name the field in `source.pointer`.
Pagination uses `limit` / `page` / `total`, and siblings support criteria.
Test with a restricted integration when the endpoint is ACL-guarded.

### Console commands

The operator starts at `bin/console list` and `bin/console <command> --help`.
Run the command from the worktree inside the instance's container (the exact form is what `attach.sh` prints for `bin/console`), so each version runs its own code against its own database.
`-n` is the non-interactive run; `--json` / `--format` is the machine-readable mode where siblings have one.

### Config, env vars, manifests

The starting points are the `.env` template, the bundled default config, `config.xml` labels and help texts, and the manifest XSD documentation.

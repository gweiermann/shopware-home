# Running and babysitting a Shopware PR

What the generic `pr-review`, `user-review` and `babysit-pr` skills need to know about Shopware.

## Run a PR end to end

Instances, their domains and database rules: the `shopware-local-dev` skill.
Worktrees: the `shopware-worktree-dev` skill.

1. **Reuse** a backend already serving the PR head: `devboard.py list` and `docker compose exec web ps -eo pid,args` in each instance.
2. **Build one beside an instance**, without touching its checkout:
   - Create the PR worktree inside the instance (`git -C <instance> worktree add .claude/worktrees/<name> <ref>`) and attach it.
   - Pick a free database name (`SHOW DATABASES`) and port (`ss -ltn` in the container).
     `CREATE DATABASE IF NOT EXISTS` on an existing name silently overwrites someone else's environment.
   - Copy the instance database into `shopware_pr<n>_<suffix>`, then run `database:migrate --all` from the worktree with `DATABASE_URL` pointing at the copy.
   - Serve the worktree's PHP from inside the container:
     `PHP_CLI_SERVER_WORKERS=8 php -S 0.0.0.0:<port> -t public public/index.php`, with `DATABASE_URL`, `APP_URL=http://localhost:<port>` and `SHOPWARE_HTTP_CACHE_ENABLED=0` as env vars.
   - Start the worktree's admin dev server with the same `APP_URL`, so it proxies to that backend.
3. **Take over** a disposable instance (`shopware-local-dev`, "What agents may change") and that no session is using.

Make the journey real: `plugin:refresh` and `plugin:install --activate` for extensions, `bin/console user:create` for users (`admin=0` for restricted ones), rows through the API or SQL on the PR database.
A broken boot (failing `bundle:dump`, a plugin config the branch rejects) is yours to repair: `attach.sh --skip-plugin <name>`, clear `var/cache`.

Browser: Playwright MCP on the `localhost` URLs `attach.sh` prints.

Surfaces and personas for a user review: [review-surfaces.md](review-surfaces.md).

## Review knowledge

- Breaking changes: `shopware-breaking-changes`, and `shopware-admin-breaking-changes` for Administration diffs.
- `UPGRADE-<major>.md` speaks from the released major: "removed" is correct for something only deprecated today.
  `RELEASE_INFO-<minor>.md` speaks about the current minor.
- A platform PR with a SwagCommercial or Rufus companion: `shopware-commercial-companion`.

## Babysitting in shopware/shopware

- Merge method: squash. Bases: `trunk`, or a release branch for backports.
- Drafts get no Codex review; wait with `--until green`.
- Stacked PRs on a non-trunk base report no required checks; gate on trunk's aggregate jobs:

  ```bash
  pr-wait <pr> --repo shopware/shopware --until green \
    --required admin-check,check,downstream-check,php-check,storefront-check \
    --quiet-user shopwareBot
  ```

- Never merge trunk into a layer while its CI still runs, unless trunk carries a fix a failing check needs: every push restarts CI and the stack never settles.
- Merge trunk into the bottom layer, then each layer into the next. Merging trunk into a middle layer drags every trunk commit into that PR's diff, turns the CLA check red and pings unrelated code owners.
- Temp branches get a unique prefix (`babysit-tmp/…`); other sessions keep `stack/*` branches in the shared repo.

### Visual snapshot failures

Download the results artifact (`gh run download <run-id> -n <artifact> -D <dir>`) and compare `*-expected.png`, `*-actual.png` and `*-diff.png` with what the PR intends.
An intended change is updated in the same container the workflow runs, from the worktree root, against the attached instance:

```bash
PLAYWRIGHT_VERSION=$(jq -r '.packages["node_modules/playwright-core"].version' package-lock.json)
docker run --rm --ipc=host --init --network=host --user "$(id -u):$(id -g)" \
  -v "$PWD:/app" -w /app/tests/acceptance \
  "mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-noble" \
  npx playwright test --project=Visual --workers=1 --update-snapshots=changed --grep="<test title>"
```

Commit only the `*-snapshots/*.png` files that changed.

### A base branch that gets rewritten

A base rewritten by force-push leaves the stacked PR DIRTY with conflicts that only come from new commit SHAs.
Merge it first on every wake; for each conflicted file, an empty `git diff --stat <previous base sha> origin/<base> -- <file>` means take `--ours`.
Afterwards `git diff --stat origin/<base>` lists only the PR's own files.

When such a base lands in trunk as a squash, `git merge origin/trunk` conflicts everywhere. Rebuild the merge instead:

```bash
git diff <last merged base tip> HEAD > pr.patch
git merge --no-commit -s ours origin/trunk
git read-tree -u --reset origin/trunk
git apply --3way --index pr.patch
git commit
```

---
name: shopware-worktree-dev
description: Run Shopware Administration work from a git worktree — attach it to a local instance for jest, eslint, phpunit and its own vite dev server against a shared backend, and route fixes into the meteor or acceptance-test-suite checkout instead of patching around them. Use BEFORE any test, lint, build or dev-server command from a worktree, before opening the admin for a worktree, when a worktree command fails on a missing node_modules, vendor, var/ or an unresolved import, whenever the cause of a bug sits in an mt-* component or an ATS helper rather than in Shopware, and when asked which instances or dev servers are running.
license: MIT
---

# Shopware worktree dev

A worktree is a bare checkout: no `vendor/`, no `node_modules`, no `var/`, no
`.env`. Every Shopware test, lint and build command needs at least one of those,
so they all fail in a fresh worktree until it is **attached** to an instance.

Attaching costs seconds and needs no lock. Instances are not the scarce resource
— see [[shopware-local-dev]] for the instance-side map, domains and repair
ladder. This is the Shopware adapter of the generic `worktree-attach` pattern.

## Attach first

```bash
~/.claude/skills/shopware-worktree-dev/attach.sh --subject '<issue/PR number + one-line goal>'   # from the worktree root
```

The subject names the worktree on the [dashboard](#dashboard); pass it on the
first attach, after which it is remembered and `--subject` can be left off.

Idempotent, so re-run it freely. It prints either `READY` plus the exact jest /
eslint / phpunit / dev-server commands for this worktree, or `NOT READY` plus
numbered steps for you to run. **Done when it prints `READY`** — run its printed
steps, then attach again, until it does.

Run every command it prints from the instance directory, targeting the
worktree's container path. Work in the worktree; never `cd` into the instance
checkout to edit or switch branches.

The backend is always the worktree's *own* instance — that container mounts that
instance's root, so no other stack can see this worktree. Pick the instance when
you create the worktree, if its version matters:

```bash
git -C ~/Documents/shopware-third worktree add .claude/worktrees/<name>
```

## Dashboard

```bash
~/.claude/skills/shopware-worktree-dev/devboard.py serve --open   # live page, http://localhost:5299/
~/.claude/skills/shopware-worktree-dev/devboard.py list           # same data as text
~/.claude/skills/shopware-worktree-dev/devboard.py subject '<text>'  # rename the current checkout
```

Lists every running instance and, under it, each dev server with its URL,
subject, branch, PR link and a VS Code link to the checkout. It discovers dev
servers by scanning each `web` container for node processes on a public port,
so any vite or webpack watcher started there shows up without registering it.
The subject is stored in the checkout's git dir (`devboard-subject`), so it is
never committed and is deleted with the worktree. Instance checkouts take a
subject the same way, run from the instance directory.

## What is shared, and what skews

The container mounts the instance root as `/var/www/html`, so a worktree under
`.claude/worktrees/` is already inside the container. A worktree elsewhere
(`~/.t3/worktrees/shopware/...`) needs two mirror mounts on the `web` service,
its parent directory and the instance root, each at its own host path;
`attach.sh` prints the exact `compose.override.yaml` lines when they are missing.
Adding them recreates the container, which stops every dev server running in it.
Attaching supplies the rest from the instance:

| Resource | How | Skews when |
|---|---|---|
| `node_modules` | cloned from `~/.shopware-nm/<package-lock hash>/` | lockfiles differ → that hash needs its own `npm ci` |
| `vendor/` | cloned from the instance + `composer dump-autoload` | `composer.lock` differs → needs `composer install` |
| `custom/plugins/*` | symlink per plugin | a plugin is installed after attaching |
| `var/`, `.env` | generated, `PROJECT_ROOT` rewritten | never |
| backend (`/api`, DB) | vite proxies to the instance's `APP_URL` | API or entity schema changed between branches |
| `tests/acceptance/node_modules` | cloned by `link-local.sh ats`, on demand | lockfiles differ → needs its own `npm ci` |

Cloning, not symlinking, and for two different reasons. `vendor/` symlinked
makes PHP resolve `__DIR__` through the link, so the autoloader's `$baseDir`
lands on the instance and you silently test the *instance's* source.
`node_modules` symlinked makes vite serve dependency assets through
`/@fs/<path outside the worktree>`, which its own `fs.allow` answers with a 403
(fonts, svgs). Both clones are APFS `clonefile` calls: seconds, and no disk.

## Troubleshooting

**`Failed to load native binding` (jest, eslint).** The command ran on the host.
`node_modules/@swc/core` here ships Linux binaries only. Run it in the container.

**`normalizeReporters` throws (jest).** `--reporters=default` collides with the
config's own reporters. Leave it off.

**`imported but could not be resolved` (vite).** The worktree's `node_modules`
does not match its lockfile. `attach.sh` checks every tree with
`~/bin/npm-tree-matches-lock`, so re-running it replaces a stale one. Compare
the branch's pin with the installed version:

```
"@shopware-ag/meteor-component-library": "5.7.1"   # branch wants
5.3.2                                              # store has
```

**`ENOENT: no such file or directory, scandir '.../custom/plugins/<X>'`.** A
plugin is active in the shared DB but absent from the worktree. Re-run
`attach.sh` to symlink it, or set `SKIP_<TECHNICAL_NAME>=1` (upper snake case) to
drop it from the build.

**Vite starts but the admin is blank or 404s on hashed chunks.** Stale browser
boot, not a build failure — the fix is in [[shopware-local-dev]].

**`bin/console` anything fails.** It needs `vendor/` and a reachable DB. Confirm
`vendor/autoload.php` exists in the worktree and the backend's `database`
service is up before reading further into the error.

**`Invalid type for path "shopware.…"` from `bundle:dump`.** An instance
plugin ships config for the instance's branch, and this branch's kernel rejects
it (seen: SwagCommercial's `major: true` after trunk made `major` a version
string). The kernel skips plugins whose files are absent, so leave it out:
`attach.sh --skip-plugin SwagCommercial`. The skip is remembered per worktree.
Then add `SKIP_<TECHNICAL_NAME>=1` to the vite command too, if the shared DB
still lists it.

## Fix it upstream

Three repos back the Administration, and a symptom you see in it often has its
cause in one of the other two:

| Checkout | Package | Owns |
|---|---|---|
| `~/Documents/meteor` | `@shopware-ag/meteor-component-library` | every `mt-*` component; pnpm workspace, code in `packages/component-library` |
| `~/Documents/acceptance-test-suite` | `@shopware-ag/acceptance-test-suite` | the page objects, fixtures and helpers `tests/acceptance` imports |

Route the fix before writing it. When the wrong behaviour lives inside an `mt-*`
component or an ATS helper, the change belongs in that repo — reaching for a
wrapper component, an override, a `:deep()` selector, a re-implemented helper or
a copied-out fixture to avoid touching upstream is the failure mode this section
exists to prevent. Fix it where it is wrong, then prove it from the consumer.

### Prove it from the worktree

```bash
~/.claude/skills/shopware-worktree-dev/link-local.sh meteor
~/.claude/skills/shopware-worktree-dev/link-local.sh ats
~/.claude/skills/shopware-worktree-dev/link-local.sh meteor --restore
```

It replaces the installed package's `dist/` with a clone of the local build and
clears vite's prebundle cache, reporting the checkout it took the build from —
path, branch, and whether it is dirty. Copy-on-write, so the `~/.shopware-nm`
store and every other worktree keep the published build. Nothing watches
`dist/`: rebuild upstream and re-run it after every upstream edit.

**Bare, it links the main checkout** — `~/Documents/meteor`,
`~/Documents/acceptance-test-suite`. Work done on a branch in a worktree of
either needs `--from`, which takes a repo root, a package directory, or the
name of a worktree under `<repo>/.claude/worktrees/`:

```bash
link-local.sh meteor --list                      # every checkout, its version and build date
link-local.sh meteor --from mt-select-flip-a1b2   # a worktree, by name
link-local.sh meteor --from ~/Documents/meteor-pr1351
```

Read the printed path before reading any result. A link from the wrong checkout
succeeds exactly like a link from the right one, and the main checkout's `dist/`
is usually an old build of a different branch. `--list` and the
"other checkouts" notice exist to make that visible; a `STALE BUILD` warning
means `src/` is newer than `dist/` and the link would carry the older build.

### A version mismatch is a decision

`link-local.sh` compares the local checkout's version against the worktree's
pin, because linking across that gap means the result you read is not the
result the pinned version gives. Either check out the matching tag upstream,
or bump the pin and treat the bump as part of the change.

### Both checkouts are the user's own working copies

Both carry in-progress branches and uncommitted edits. Read `git status` before
touching either, and leave branch switching, stashing and committing there to
the user unless they asked. Own work belongs in a worktree of that repo, linked
with `--from`, rather than in the checkout itself.

### Landing order

1. PR in the upstream repo — merged and released.
2. A separate Shopware PR bumping the pin in `package-lock.json`.
3. Anything in Shopware that *depends* on the new behaviour waits for step 2.

When the Shopware side genuinely cannot wait, say so in the PR description:
name the temporary shape and the upstream PR that removes it, so it is a
declared bridge rather than a silent workaround.

## Sharing one backend

Several worktrees on one backend is the normal case: each vite dev server serves
the admin document itself and proxies `/api`, so the backend only answers API
calls. Ports need no publishing — the OrbStack domain routes every container
port, so the worktree's admin is at `http://<instance-domain>:<ADMIN_PORT>/`.
Reach it by domain, not by the container's IP: a sandboxed browser such as the
Playwright MCP one gets `ERR_ADDRESS_UNREACHABLE` on the IP.

Open it in a browser at `http://localhost:<ADMIN_PORT>/` (`attach.sh` prints it).
Browser agents may only type the test login on `localhost`, so `attach.sh` starts
`forward.mjs`, a raw TCP forwarder `localhost:<ADMIN_PORT>` → `<instance-domain>:<ADMIN_PORT>`.
It survives the shell and is reused on the next attach.
If vite falls back to a higher port because `ADMIN_PORT` was busy, forward that one by hand:

```bash
nohup node ~/.claude/skills/worktree-attach/scripts/forward.mjs <instance-domain> <port> >/dev/null 2>&1 &
```

Every worktree attached to an instance shares its database. Migrations are
forward-only (`MigrationStep` has `update()` and `updateDestructive()`, no
`down()`), so a version switch, `composer setup` or `database:migrate` hits every
attached worktree at once. Which databases you may change, and when to switch to
a copy of your own, is in [[shopware-local-dev]] under "What agents may change".

Attaching, starting a dev server, and running jest / eslint / phpunit / phpstan
leave the database alone. Do those freely.

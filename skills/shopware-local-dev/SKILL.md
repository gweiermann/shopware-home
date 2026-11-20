---
name: shopware-local-dev
description: Create, access and repair the local Shopware dev instances (full shopware/shopware checkouts running in Docker under <name>.orb.local). Use BEFORE opening or curling an instance URL, before rebuilding the admin, when no instance exists yet or all are busy, or when one is broken - 500 error, white page, stale UI, "changes not showing", old cache.
license: MIT
---

# Shopware local dev instances

An **instance** is a full `shopware/shopware` checkout running its own Docker stack (its `compose.yaml`: web, database, OpenSearch, Valkey, Mailpit, Adminer) via OrbStack, reachable at `http://<name>.orb.local`.
Instances are playgrounds for agents; [what agents may change](#what-agents-may-change) has the one exception.

**In a git worktree?** Follow `shopware-worktree-dev` first: a worktree runs against an instance, it does not need one of its own.

## Which instances exist

```bash
~/.claude/skills/shopware-worktree-dev/devboard.py list   # running instances, domains, attached dev servers
```

Instances live in the home repo's `repositories/shopware/shopware-<n>`, at `http://shopware-<n>.orb.local`.
Each one's `compose.override.yaml` holds its domain and host ports.

OrbStack routes the domain straight to the container's port 8000: use it **without a port**.
A browser that has to log in (any browser agent) uses `http://localhost:<host port>/admin` instead, because agents may only type the test login on `localhost`.
Login: `admin` / `shopware`.

Domains stay under `.orb.local`.
A custom `.local` suffix that a network's DHCP also hands out as its search domain (the Shopware office hands out `shopware.local`) makes macOS race unicast DNS against mDNS, and the name resolves only until the next cache flush.

## Creating an instance

- **None yet, or all busy** (other sessions run version switches, migrations or long jobs on them) **and the machine has room** (Docker memory and disk; each stack needs a few GB of both): `bin/setup-shopware-instance.sh --name shopware-<n> --index <n + 2>` from the home repo.
  It clones `trunk`, offsets the host ports by `index * 100`, ups the stack and installs; `--demodata` adds demo data.
- **Cap: three instances.** Beyond that, share one: worktrees attach to busy instances fine, and a run that would disturb others gets its own database copy (below).

Every web container mounts the external `shopware-pkg-cache` volume as its composer and npm download cache; a hand-written override needs the same lines the script writes.
`vendor/` and every `node_modules` come from `~/.shopware-nm/<lockfile hash>/` as copy-on-write clones; `shopware-instance` fills and reads it.

## What agents may change

How much each instance matters is the user's call, saved under "Instances" in `~/.agents/shopware-home/preferences.md`.
No answer yet ⇒ ask once which level each instance has; disposable is a fine answer for all of them.

**Disposable** (the default for instances agents set up and maintain themselves): migrate, reset, seed, clone or break the database to get the job done, without asking.
Repair or reset what you broke when you are done.

**Keep usable**: the user clicks around in it themselves. Anything goes as long as you leave it working: latest trunk's schema, demo data, the admin login.
Broken ⇒ repair it before you are done, and tell the user.

**Keep data**: as "keep usable", and its data stays: no reset, no test rows, no PR migrations.
Reading it and dumping it as a seed for a copy are fine.

**Own database when you would get in others' way.** Other sessions share each instance.
When your run leaves the database where another session would have to reset it (a PR's migrations, a version switch, bulk rows), or holds it busy for long, use a copy: create `shopware_<purpose>` (check the name is free first), load a dump of the instance database, and pass `-e DATABASE_URL=mysql://root:root@database/<copy>` on every `docker compose exec`; the container's `DATABASE_URL` env var beats `.env.local`.

**Checkouts stay the user's.** Each instance checkout holds the user's own branch and uncommitted work.
Work in a worktree; leave `git checkout`, `switch` and `stash` in the instance checkout to them.

## Running commands

Commands run inside the container, from the instance directory, with `-T` for non-interactive use:

```bash
cd repositories/shopware/shopware-1 && docker compose exec -T web <cmd>
```

`exec` fails ⇒ the stack is not up: `docker compose up -d web database` there first.

**npm and npx never run on the host.** `node_modules/@swc/core` ships Linux binaries only, so host jest and the ESLint import resolver die with "Failed to load native binding".
Jest positional patterns often match nothing; pass exact paths with `--runTestsByPath`.

## Build vs. watch

- `composer watch:admin`: hot reload; if a watch server or a worktree dev server is up, just refresh.
- `composer build:js:admin`: only to see changes on the plain domain without a watch server. Slow.

## Repair ladder

Cheapest first, from the affected instance directory:

1. `docker compose exec -T web bash -c 'rm -rf var/cache && bin/console cache:clear'`
2. `docker compose exec -T web bin/console database:migrate --all`
3. `shopware-instance update` (host): deps from the store + migrations.
4. `shopware-instance reset` (host): reinstall + demo data. **Wipes the database**; never on a "keep data" instance, and a "keep usable" one gets its demo data back.
5. Demo data only: `docker compose exec -T web bash -c 'APP_ENV=prod bin/console framework:demodata'`. Check counts first; it duplicates.

Never replace 3–4 with a bare `composer setup`: that installs everything from scratch, 5–12 minutes.
Still broken: `docker compose ps`, `docker compose logs web --tail=50`.

**404 on a hashed chunk** after a build is a stale browser boot: clear caches, service workers and storage in the browser, then load `/admin?cb=1`.
Use http, not https.

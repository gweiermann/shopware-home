# Breaking Surface & Worked Examples

Read this only after step 1 of the test in `SKILL.md` came out positive — the
symbol **exists in `origin/trunk`**. Everything here assumes that.

## What counts as public surface

Public means: a third party on a released Shopware can depend on it without
reaching into internals.

**PHP**
- Non-`@internal` classes, interfaces, abstract classes, traits, enums and their
  public/protected members.
- Constructor signatures of non-`@internal`, non-`@final` services (extensions
  decorate them).
- Events, event names, and event payload getters.
- Public DI service ids, service tags, and container parameters.
- Thrown exception classes and their factory methods when documented.

**Data Abstraction Layer**
- Entity names, entity definitions, field names, field types, nullability.
- Association names and cardinality, `Criteria` behaviour of existing filters.
- Database columns backing public entities (removal needs a destructive
  migration and an upgrade note).

**HTTP APIs**
- `/api`, `/store-api`, `/api/_action/sync` route paths, methods, required
  parameters, and response shape.
- OpenAPI schema under
  `src/Core/Framework/Api/ApiDefinition/Generator/Schema/<AdminApi|StoreApi>/paths`.
- Response status codes and error codes.

**Storefront**
- Template paths and Twig block names (themes extend and override them).
- Variables available in the render context.
- SCSS variables, mixins, and class names themes build on.
- JS plugin names and their registered options.

**Administration**
- Component names, their props, emitted events, slots, and the blocks/overrides
  other code can target.
- Anything on the `Shopware` global (service container ids, `Component`,
  `Application`, stores/state modules).
- Snippet keys that are referenced from outside core.

**Configuration & operations**
- `config.xml` keys and their defaults, bundle configuration keys, env vars.
- Feature-flag names once documented, CLI command names, arguments, options.
- Default values: changing one is a behavioural break even when the key stays.

## Not public, even when it exists in trunk

- Anything marked `@internal`, including its constructor and members.
- `private`/`protected` members of `@final` classes.
- Test code, fixtures, and test helpers.
- Implementation details of a documented contract: internal method order,
  log wording, private query shape.
- Behaviour that was a bug. Fixing a bug is a fix, not a break — but say so in
  the PR if consumers could reasonably have depended on it.

## Worked examples

**1 — Rename a method added two PRs ago in the same stack**
Symbol not in `origin/trunk`. **Not breaking.** Rename it, update the callers
in the same commit, adjust the `RELEASE_INFO` entry the earlier PR wrote. No
deprecation, no alias.

**2 — Change the signature of an `@internal` core service that plugins do call**
`@internal` is the contract. **Not breaking.** Do not add a BC layer. If the
service is genuinely useful externally, that is a separate design discussion —
raise it, do not smuggle in a public API.

**3 — Remove a public non-`@internal` method from a service in trunk**
**Breaking.** Deprecate it for the current major with
`Feature::triggerDeprecationOrThrow()`, keep it working, add the replacement,
document both in `RELEASE_INFO-6.<minor>.md` and `UPGRADE-6.<next-major>.md`.
Removal happens in the next major only.

**4 — Change a DAL field from nullable to required**
**Breaking** — writes that used to succeed now fail. Needs a migration, an
upgrade note with the data-fix path, and usually a feature-flagged rollout.

**5 — Add a required parameter to an existing public Store API route**
**Breaking.** Add it optional with the previous behaviour as default, document
the future requirement in the upgrade guide.

**6 — Rename a Twig block in a storefront template that exists in trunk**
**Breaking** for themes. Keep the old block wrapping the new content for the
current major, or do the rename behind the next-major flag.

**7 — Delete a file that only your branch ever created**
**Not breaking.** Not even worth a note.

**8 — Your branch changes an Admin component prop you introduced in PR 01**
**Not breaking.** Update PR 01's tests and callers so the stack is coherent.

**9 — A trunk integration test fails after your change**
Read the assertion. If it pins a public contract, you have a real break — go to
`shopware-release-docs`. If it pins an implementation detail, update the test
and say why in the commit message.

**10 — Merged to trunk last week, never released, now needs a different shape**
No released consumer exists. Change it, and flag the call in the PR
description rather than deciding a compat layer on your own.

## After a real break is confirmed

1. `shopware-php-code` → deprecation mechanics, `Feature::silent`, feature-flag
   guards, migration rules.
2. `shopware-release-docs` → which entry goes in `RELEASE_INFO-6.<minor>.md`
   versus `UPGRADE-6.<next-major>.md`, written from the consumer's perspective.
3. `shopware-change-scope` → keep the fix at the root cause instead of
   spreading a compat layer across callers.

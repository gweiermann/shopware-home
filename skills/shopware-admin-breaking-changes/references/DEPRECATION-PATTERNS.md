# Deprecation Patterns

The remedy for almost every `breaking` finding is the same: **add the replacement, keep the old thing working, annotate it, remove it in the next major.** These are the exact shapes the [Shopware backward-compatibility guideline](https://developer.shopware.com/docs/resources/guidelines/code/backward-compatibility.html) prescribes. Use them when you propose a fix — a review comment that says "deprecate it instead" without the shape is not actionable.

Annotation format is always `@deprecated tag:vX.Y.Z - <what to use instead>`. Name the replacement; a bare tag helps nobody.

## 1. Twig block

Keep the block, mark it with the Twig `deprecated` tag:

```twig
{% block the_block_name %}
    {% deprecated '@deprecated tag:v6.8.0 - Block will be removed completely including the content' %}
    <div>Content</div>
{% endblock %}
```

Renaming a block means shipping both: the new block wrapping the content, the old block kept around it and annotated.

## 2. Vue slot

Both slots ship for one major. The old one keeps working, the new one is what you document:

```twig
{# @deprecated tag:v6.8.0 - Use slot "main-content" instead #}
<slot name="content"></slot>
<slot name="main-content"></slot>
```

## 3. Component

Register the replacement, annotate the old registration, and set the `deprecated` component option so the runtime can warn:

```javascript
/**
 * @deprecated tag:v6.8.0 - Use sw-new instead
 * @status deprecated
 */
Shopware.Component.register('sw-old', {
    deprecated: '6.8.0',
});
```

## 4. Method rename

The old method stays and delegates. Never leave a rename without the shim:

```javascript
/**
 * @deprecated tag:v6.8.0 - Use onItemClick() instead
 */
onClick(event) {
    return this.onItemClick(event);
},

onItemClick(event) {
    // …
},
```

## 5. Changed return value or signature

Do not change the old method — add a new one beside it:

```javascript
export default class RouteService {
    /**
     * @deprecated tag:v6.8.0 - Use getRouteConfig() instead
     */
    getRoute(symfonyRoute) {
        return this._someMagic(symfonyRoute);
    }

    getRouteConfig(symfonyRoute) {
        return {
            url: this._someMagic(symfonyRoute).url,
            params: this._someMagic(symfonyRoute).params,
        };
    }
}
```

The only signature changes that need no new method: adding an **optional parameter with a default**, or adding a key to a parameter object the method already destructures.

## 6. Property

Annotate and declare the `deprecated` option so tooling and the runtime both see it:

```javascript
{
    name: 'example-component',
    props: {
        /** @deprecated tag:v6.8.0 - Use `items` instead */
        exampleProp: {
            type: String,
            required: false,
            default: 'Default value',
            deprecated: {
                version: '6.8.0',
                comment: 'Use `items` instead',
            },
        },
    },
}
```

## 7. A property that must become required

Never flip `required: false` to `required: true` in one release. Add it optional, warn when it is missing, make it required in the next major:

```javascript
{
    createdComponent() {
        /** @deprecated tag:v6.8.0 - Warning will be removed when prop is required */
        if (!this.newProp) {
            debug.warn(
                'sw-example-component',
                '"newProp" will be required in tag:v6.8.0',
            );
        }
    },
}
```

The same shape applies to a route parameter that must become required.

## 8. Asset

Ship the replacement, keep the old file, and register the old path in the build-time deprecation list at `build/vite-plugins/image-deprecation/deprecated-list.ts`:

```typescript
export default [
    '/static/img/sw-login-background.png',
    // …
];
```

Every import of a listed path prints a build warning naming the importing file. Remove the file itself only in the next major, with an `UPGRADE` entry.

## 9. What none of this covers

Deprecation buys a migration window; it does not make the change non-breaking. Every deprecation still needs its `UPGRADE-6.8.md` entry describing the removal, plus a `RELEASE_INFO-6.<minor>.md` entry announcing the replacement — see `shopware-release-docs`.

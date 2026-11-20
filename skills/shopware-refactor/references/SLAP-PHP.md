# SLAP — PHP

Worked examples for PHP under `src/Core`, `src/Administration`, `src/Storefront`.
Load when a split is not obvious, or when you are unsure whether an extraction
earns its name. For Admin JS/TS/Vue see [`SLAP-ADMIN-JS.md`](SLAP-ADMIN-JS.md).

## Example 1 — policy and mechanism in one method

The tell is the section comments: each one names a step the code refused to
name. A second tell is `Criteria` plumbing and array arithmetic sitting next to
the business sentence "cancel every abandoned order".

**Before**

```php
public function cancelAbandonedOrders(Context $context): int
{
    // find candidates
    $criteria = new Criteria();
    $criteria->addFilter(new EqualsFilter('stateMachineState.technicalName', 'open'));
    $criteria->addFilter(new RangeFilter('createdAt', [
        RangeFilter::LTE => (new \DateTimeImmutable('-30 days'))->format(Defaults::STORAGE_DATE_TIME_FORMAT),
    ]));
    $criteria->addAssociation('transactions');
    $orders = $this->orderRepository->search($criteria, $context)->getEntities();

    // skip the ones that were paid after all
    $cancellable = [];
    foreach ($orders as $order) {
        $paid = false;
        foreach ($order->getTransactions() ?? [] as $transaction) {
            if ($transaction->getStateMachineState()?->getTechnicalName() === 'paid') {
                $paid = true;
            }
        }
        if (!$paid) {
            $cancellable[] = $order;
        }
    }

    // cancel and notify
    foreach ($cancellable as $order) {
        $this->stateMachineRegistry->transition(
            new Transition('order', $order->getId(), 'cancel', 'stateId'),
            $context
        );
        $this->eventDispatcher->dispatch(new OrderCancelledEvent($order->getId(), $context));
    }

    return \count($cancellable);
}
```

**After** — the public method is now a list of named steps a reader can stop at.
Each callee stays on one floor: `findStaleOpenOrders()` is Criteria mechanism,
`isPaid()` is a predicate over one entity, `cancel()` is the transition plus its
event.

```php
public function cancelAbandonedOrders(Context $context): int
{
    $cancellable = $this->findStaleOpenOrders($context)->filter(
        fn (OrderEntity $order) => !$this->isPaid($order)
    );

    foreach ($cancellable as $order) {
        $this->cancel($order, $context);
    }

    return $cancellable->count();
}

private function findStaleOpenOrders(Context $context): OrderCollection
{
    $criteria = new Criteria();
    $criteria->addFilter(new EqualsFilter('stateMachineState.technicalName', 'open'));
    $criteria->addFilter(new RangeFilter('createdAt', [
        RangeFilter::LTE => (new \DateTimeImmutable('-30 days'))->format(Defaults::STORAGE_DATE_TIME_FORMAT),
    ]));
    $criteria->addAssociation('transactions');

    return $this->orderRepository->search($criteria, $context)->getEntities();
}

private function isPaid(OrderEntity $order): bool
{
    foreach ($order->getTransactions() ?? [] as $transaction) {
        if ($transaction->getStateMachineState()?->getTechnicalName() === 'paid') {
            return true;
        }
    }

    return false;
}

private function cancel(OrderEntity $order, Context $context): void
{
    $this->stateMachineRegistry->transition(
        new Transition('order', $order->getId(), 'cancel', 'stateId'),
        $context
    );
    $this->eventDispatcher->dispatch(new OrderCancelledEvent($order->getId(), $context));
}
```

Note what did **not** happen: no new interface, no new service, no strategy
object. SLAP is about altitude inside a unit, not about growing the object graph.

## Example 2 — rule 2, "never reach up"

`isPaid()` above is reusable and unit-testable because it only inspects one
entity. The moment it dispatches an event or writes an audit log, it has taken on
the caller's job:

```php
// Reaching up — a predicate that also dispatches. Now it cannot be called
// from a read-only path, and its test needs an event dispatcher.
private function isPaid(OrderEntity $order, Context $context): bool
{
    $paid = /* … */;
    if (!$paid) {
        $this->eventDispatcher->dispatch(new OrderUnpaidDetectedEvent($order->getId(), $context));
    }

    return $paid;
}
```

Policy — deciding that an unpaid order is worth announcing — belongs in the
caller that already knows why it is asking.

The PHP-specific variants of reaching up: a repository decorator that throws a
domain exception, a `Criteria` builder that reads the `SalesChannelContext` to
decide business rules, a DAL subscriber that performs an unrelated write, an
`EntityDefinition` that knows about HTTP.

## Example 3 — rule 3, extraction that does not earn its name

```php
// Before: one clear loop.
foreach ($lineItems as $lineItem) {
    $total += $lineItem->getPrice()->getTotalPrice();
}

// "After": the name says nothing the body didn't, and the reader now has to
// jump to learn something they already knew.
$total = $this->doTheLoop($lineItems);
```

Extract when the name replaces a *how* with a *what*: `sumLineItemTotals()`
earns it, `doTheLoop()` does not. If you cannot find the better name, the mixing
was cheaper than the indirection — leave it.

## Example 4 — mechanism that deserves its own class

One floor down is usually a private method. Reach for a new class only when the
mechanism has its own state or its own vocabulary — a raw SQL query with a dozen
joins, a parser, a price calculation with intermediate rounding rules.

Signals it is a class, not a method: the private helpers only talk to each other
and never to `$this`'s other collaborators; the constructor dependencies split
cleanly in two; the unit test would want to instantiate half the object.

Keep the new class `@internal` unless it is meant as an extension point
(`coding-guidelines/core/final-and-internal.md`).

## Step-down order (rule 4)

Order members so a reader descends: constructor, then public API in call order,
then the private helpers each public method uses, then shared leaf helpers.
Existing file conventions win where they conflict.

A reader who stops after the first public method must still have a true — if
coarse — summary of the whole class.

## PHP tells worth naming

| Tell | Cut |
|---|---|
| A raw SQL string next to domain vocabulary | Push the query into a private method or an `@internal` loader class |
| `Criteria` assembly inline in a handler or controller | A named `…Criteria()` method returning the built `Criteria` |
| `array_map`/`array_filter` chains with closures three lines long | Named private methods, or a collection method |
| A method taking `Context` *and* `SalesChannelContext` *and* a bool flag | Two methods with two names |
| `if (Feature::isActive(…))` wrapped around half a method body | Two methods, one per branch, dispatched at the top (`coding-guidelines/core/feature-flags.md`) |
| `try`/`catch` around a block that mixes fetching and writing | Split, so each block has one failure mode and one exception type (`coding-guidelines/core/domain-exceptions.md`) |

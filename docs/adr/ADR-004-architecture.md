# ADR-004: Select Architecture Style (DDD)
- Status: Accepted
- Date: 2026-03-12

## Context
The app combines distinct concerns (catalog, editing, runtime execution) that can become tightly coupled without clear boundaries.

## Decision
Use Domain-Driven Design with bounded contexts and layered structure per context:
`presentation -> application -> domain -> infrastructure`.

## Consequences
- Positive:
  - Clear ownership and boundaries reduce coupling.
  - Domain logic remains testable and framework-independent.
  - Scales better as features (multi-file, sync, sharing) are added.
- Negative:
  - More upfront structure and boilerplate.
  - Requires team discipline to keep dependencies flowing inward.
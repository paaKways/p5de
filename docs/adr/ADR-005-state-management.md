# ADR-005: Select State Management (BLoC)
- Status: Accepted
- Date: 2026-03-12

## Context
UI flows (editor, runtime lifecycle, CRUD operations) are event-driven and require predictable state transitions and robust testing.

## Decision
Use BLoC/Cubit for presentation-layer state management.

## Consequences
- Positive:
  - Explicit event/state model and strong testability.
  - Predictable transitions for runtime/editor lifecycle handling.
  - Good separation between application use cases and UI state.
- Negative:
  - More boilerplate than lighter state solutions.
  - Overuse can add complexity for trivial UI state.
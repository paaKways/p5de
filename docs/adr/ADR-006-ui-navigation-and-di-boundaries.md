# ADR-006: Keep UI Pages Decoupled From AppDependencies
- Status: Accepted
- Date: 2026-03-14
- Deciders: Mobile Engineering
- Supersedes: N/A
- Superseded by: N/A

## Context
As implementation moved from Milestone 1 (catalog) into Milestone 2 (editor), UI pages started needing navigation into new flows. The initial approach passed the full `AppDependencies` container into `SketchCatalogPage` so the page could navigate to the editor and construct downstream objects.

This made widget tests brittle:
- page tests became coupled to full app wiring
- unrelated DI changes could break UI tests
- the page had implicit ownership of composition responsibilities

The team also needed fast web iteration, where tighter boundaries reduce platform-specific ripple effects.

## Decision
UI pages in bounded contexts should not receive the full `AppDependencies` container.

Instead:
- app/root composition (`lib/app`) owns DI and navigation wiring
- pages receive narrow, explicit collaborators (callbacks, bloc instances, or ports)
- for navigation from catalog to editor, `SketchCatalogPage` accepts `onOpenSketch(BuildContext, String)?`

## Alternatives Considered
- Option A: Inject `AppDependencies` into each page
  - Pros: quick to wire, fewer constructor args initially
  - Cons: high coupling, poor test isolation, layering drift
- Option B: Global service locator lookup inside pages
  - Pros: fewer constructor parameters
  - Cons: hidden dependencies, difficult testing/mocking, weak boundaries
- Option C: Page-level narrow contracts/callbacks (selected)
  - Pros: explicit dependencies, testability, cleaner architecture boundaries
  - Cons: slightly more composition code in app/root

## Consequences
- Positive:
  - Widget tests can render pages without full DI bootstrap.
  - Composition responsibilities stay in app/root layer.
  - Refactors in DI have lower blast radius on presentation tests.
- Negative:
  - More callback/constructor wiring in root composition.
  - Requires discipline to avoid backsliding to container-passing.
- Neutral:
  - This pattern can evolve into typed navigation/application ports as flows grow.

## Implementation Notes
- Scope:
  - `SketchCatalogPage` now takes `onOpenSketch` callback instead of `AppDependencies`.
  - `P5deApp` wires navigation to `EditorPage` and passes dependencies there.
- Rollout:
  - Apply this rule to new pages by default.
  - Refactor existing pages opportunistically when touched.
- Validation:
  - Widget tests for pages remain green with lightweight fakes.
  - No direct `AppDependencies` usage in bounded-context page widgets.

## Links
- Related PRD section: Sketch CRUD and editor flow
- Related TDD section: DDD layered boundaries (`presentation -> application -> domain -> infrastructure`)
- Related files:
  - `lib/app/app.dart`
  - `lib/contexts/sketch_catalog/presentation/sketch_catalog_page.dart`
  - `lib/contexts/editor/presentation/editor_page.dart`

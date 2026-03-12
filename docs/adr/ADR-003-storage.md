# ADR-003: Select Storage Layer (Drift/SQLite)
- Status: Accepted
- Date: 2026-03-12

## Context
The app needs reliable local persistence for sketch CRUD, offline-first behavior, predictable migrations, and testable repository abstractions.

## Decision
Use Drift over SQLite as the primary persistence layer.

## Consequences
- Positive:
  - Typed queries and compile-time safety.
  - Explicit migration support and stable local storage.
  - Good fit for repository pattern in DDD architecture.
- Negative:
  - Added build/codegen complexity.
  - Requires migration discipline for schema evolution.
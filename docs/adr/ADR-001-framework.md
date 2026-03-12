# ADR-001: Select App Framework (Flutter)
- Status: Accepted
- Date: 2026-03-12

## Context
The product requires a mobile-first code editor/runtime app with fast iteration, consistent UI behavior across Android devices, and strong WebView integration.

## Decision
Use Flutter as the application framework for MVP.

## Consequences
- Positive:
  - Single codebase with fast UI iteration.
  - Strong rendering consistency across device sizes.
  - Mature plugin ecosystem for WebView, SQLite, and Firebase.
- Negative:
  - WebView/plugin debugging can be more complex than pure native.
  - Team must enforce architecture boundaries to avoid monolithic Flutter code.
# ADR-002: Select Runtime Execution Model (WebView Sandbox)
- Status: Accepted
- Date: 2026-03-12

## Context
p5.js requires a browser-like JS/Canvas environment. The app must run sketches offline, isolate untrusted user code, and support start/stop/restart behavior.

## Decision
Use a dedicated sandboxed WebView runtime (`flutter_inappwebview`) loading a local HTML shell and bundled `p5.min.js`.

## Consequences
- Positive:
  - Native fit for p5.js execution model.
  - Offline runtime via bundled assets.
  - Clear lifecycle controls through WebView reload/reset.
- Negative:
  - WebView behavior can vary by Android WebView version.
  - Need careful JS bridge hardening and error mapping.
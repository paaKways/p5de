# ADR-002: Select Runtime Execution Model (WebView Sandbox)
- Status: Accepted
- Date: 2026-03-12

## Context
p5.js and the Processing Java TeaVM target both require a browser-like JS/Canvas environment. The app must run sketches offline, isolate untrusted user code, and support start/stop/restart behavior.

## Decision
Use a dedicated sandboxed WebView runtime (`flutter_inappwebview`) loading local HTML shells and bundled runtime assets:

- p5.js shell with bundled `p5.min.js`
- Processing Java shell with the TeaVM browser compiler/runtime assets and a generated browser-safe `processing.core.PApplet` shim

## Consequences
- Positive:
  - Native fit for browser Canvas execution models.
  - Offline runtime via bundled assets.
  - Clear lifecycle controls through WebView reload/reset.
- Negative:
  - WebView behavior can vary by Android WebView version.
  - Need careful JS bridge hardening and error mapping.
  - Processing Java runtime assets increase app package size and require device-level startup benchmarking.

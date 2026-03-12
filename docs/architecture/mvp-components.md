# MVP Components

This document is the Milestone 0 placeholder for the MVP architecture map.

## Planned Components
- app bootstrap and dependency injection (`lib/app`)
- sketch catalog bounded context (`lib/contexts/sketch_catalog`)
- editor bounded context (`lib/contexts/editor`)
- runtime preview bounded context (`lib/contexts/runtime_preview`)
- shared primitives (`lib/shared`)

## Planned Data/Control Flow
- Presentation -> Application -> Domain -> Infrastructure
- BLoC/Cubit stays in the presentation layer.
- Domain and application layers remain framework-agnostic.

## Next Update
Milestone 1 should replace this placeholder with a concrete component diagram and dependency graph.

# Copilot Instructions for @f3liz/rescript-autogen-openapi

## Overview

OpenAPI 3.1 → ReScript code generator that produces types + [Sury](https://github.com/DZakh/rescript-schema) runtime validation schemas. Supports multi-fork strategies (e.g., Misskey vs Cherrypick) with shared base code and fork-specific extensions via diff/merge.

## Build & Test

```bash
npm run build        # rescript compile + generate .d.ts files
npm run clean        # rescript clean
npm run watch        # rescript build -w (no .d.ts generation)
npm test             # node --test (runs tests/codegen.test.mjs)
```

The build is two-phase: `rescript` compiles `.res` → `.mjs`, then `scripts/generate-dts.mjs` converts `@genType`-produced `.gen.ts` files into `.d.ts` declarations under `lib/es6/src/`.

Tests use Node.js built-in test runner (`node:test`). To run a single test:
```bash
node --test --test-name-pattern="Diff Mode" tests/codegen.test.mjs
```

## Architecture

### Pipeline (src/core/Pipeline.res)

The generation pipeline flows: **OpenAPI Spec → Parse → IR → Generate Code**

1. `OpenAPIParser` / `SchemaRefResolver` — parse and resolve `$ref` references
2. `SchemaIRParser` / `IRBuilder` — convert OpenAPI schemas to a unified **Intermediate Representation (IR)**
3. Generators consume the IR to produce different outputs

### Generators (src/generators/)

Each generator targets a specific output:
- `ComponentSchemaGenerator` — ReScript types + Sury schemas for `#/components/schemas`
- `ModuleGenerator` — per-tag or flat endpoint modules
- `EndpointGenerator` — individual endpoint request/response code
- `IRToSuryGenerator` / `IRToTypeGenerator` — IR → Sury schema code / ReScript type code
- `ThinWrapperGenerator` — pipe-first ergonomic wrapper module
- `TypeScriptDtsGenerator` / `TypeScriptWrapperGenerator` — TypeScript outputs
- `DiffReportGenerator` — markdown reports comparing fork differences

### Multi-Fork Strategy

`SpecDiffer` compares two OpenAPI specs; `SpecMerger` extracts shared endpoints. The `SharedBase` strategy generates a base directory plus per-fork extension directories.

### Entry Point

`Codegen.res` orchestrates everything. Key exported functions:
- `generateFromFile` / `generateFromUrl` — main generation entry points
- `compareSpecs` — diff two parsed specs
- `generate` — config-driven generation (used by downstream consumers like rescript-misskey-api)

## Conventions

- **ReScript 12 + ESM only** — all output is `.mjs`, no CommonJS
- **`@genType`** on public API functions in `Codegen.res` for TypeScript interop
- **`sury`** is a peer dependency — generated code imports it for runtime schemas
- **Result types** — generation functions return `result<Pipeline.t, codegenError>`, check `result.TAG === 'Ok'`
- **Module naming** — API modules use PascalCase derived from OpenAPI tags (e.g., tag `admin/accounts` → `AdminAccounts.res`)
- **License headers** — source files use `// SPDX-License-Identifier: MPL-2.0`
- **Warnings config** — `-44` (open shadow) and `-102` (polymorphic comparison) are suppressed in `rescript.json`

# @f3liz/rescript-autogen-openapi Examples

This directory contains examples demonstrating the capabilities of `@f3liz/rescript-autogen-openapi`.

## Core Capabilities

**Multi-Fork Support**: Handles multiple API forks (such as Misskey, Cherrypick, Firefish) by extracting shared code and generating fork-specific extensions.

**Unified IR Pipeline**: Uses a unified intermediate representation to generate both ReScript types and Sury validation schemas.

**Real-World Tested**: Validated against Misskey/Cherrypick APIs (400+ endpoints).

---

## 📚 Examples

These examples use local OpenAPI fixtures found in `examples/fixtures/` for fast, reliable, and "down-to-earth" demonstrations.

### Example 1: Generate from Single Spec
**File**: `01-generate-single-spec.mjs`

Generates a type-safe API client from a local Petstore spec.

```bash
node examples/01-generate-single-spec.mjs
```

**Functionality:**
- Parses local `petstore.json`
- Generates ReScript types and Sury validation schemas
- Creates per-tag modules (e.g., `Pets.res`)

---

### Example 2: Compare Two Specs
**File**: `02-compare-specs.mjs`

Compares two versions of the Petstore API to identify differences.

```bash
node examples/02-compare-specs.mjs
```

**Functionality:**
- Compares `petstore.json` and `petstore-extended.json`
- Detects added endpoints and modified schemas
- Generates a markdown diff report

---

### Example 3: Multi-Fork with Shared Base
**File**: `03-generate-multi-fork.mjs`

Extracts shared code between two specs and generates fork-specific extensions.

```bash
node examples/03-generate-multi-fork.mjs
```

**Functionality:**
- Identifies common endpoints between base and extended specs
- Generates shared modules for common functionality in `petstore-base/`
- Generates extension modules for unique endpoints in `extended/`
- Maximizes code reuse across API variants

---

## 🚀 Quick Start

### Prerequisites

```bash
npm install
npm run build
```

### Run Examples

```bash
# Example 1: Single spec
node examples/01-generate-single-spec.mjs

# Example 2: Compare specs
node examples/02-compare-specs.mjs

# Example 3: Multi-fork
node examples/03-generate-multi-fork.mjs
```

---

## 🛠️ Local Fixtures

The examples use the following local specs:

- `examples/fixtures/petstore.json`: Base API with `pets` endpoints.
- `examples/fixtures/petstore-extended.json`: Extended API adding `store` endpoints and modifying `Pet` schema.

---

### Example 4: Real-World Multi-Fork (Misskey & Cherrypick)
**File**: `04-misskey-multi-fork-manual.mjs`

A heavy-duty example using real-world specs with 400+ endpoints.

```bash
node examples/04-misskey-multi-fork-manual.mjs
```

**Functionality:**
- Fetches `misskey.io` and `kokonect.link` specs
- Performs full multi-fork extraction and generation
- Generates comprehensive diff and merge reports


---

## 📖 Understanding the Output

### ReScript Types

Generated types are compatible with ReScript's type system:

```rescript
type createNoteRequest = {
  text: option<string>,
  visibility: [#public | #home | #followers | #specified],
  localOnly: option<bool>,
}

type createNoteResponse = {
  createdNote: note,
}
```

### Sury Validation Schemas

Runtime validation schemas using [Sury](https://github.com/DZakh/rescript-schema):

```rescript
let createNoteRequestSchema = S.object(s => {
  text: s.field("text", S.option(S.string)),
  visibility: s.field("visibility", S.union([
    S.literal("public"),
    S.literal("home"),
    S.literal("followers"),
    S.literal("specified"),
  ])),
  localOnly: s.field("localOnly", S.option(S.bool)),
})
```

---

## 🎨 Configuration Options

Examples use a configuration object:

```javascript
const config = {
  specPath: 'https://example.com/api.json',
  outputDir: './generated',
  strategy: 'SharedBase',           // 'Separate' | 'SharedBase'
  modulePerTag: true,
  generateDiffReport: true,
  
  // Multi-fork configuration
  forkSpecs: [
    { name: 'cherrypick', specPath: 'https://kokonect.link/api.json' },
  ],
};
```
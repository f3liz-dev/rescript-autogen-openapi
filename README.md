# @f3liz/rescript-autogen-openapi

Generate ReScript code with [Sury](https://github.com/DZakh/rescript-schema) schemas from OpenAPI 3.1 specs. Supports multiple forks with intelligent diff/merge capabilities.

## 🎯 Features

*   **Type-Safe ReScript Code**: Generates ReScript types for all request/response schemas.
*   **Runtime Validation**: Generates Sury validation schemas for runtime safety and parsing.
*   **Multi-Fork Support**: Intelligently handles multiple API forks (like Misskey, Cherrypick, Firefish) by extracting shared code and generating fork-specific extensions.
*   **Unified IR Pipeline**: Advanced type inference with a unified intermediate representation that generates both types and schemas.
*   **Diff & Merge**: Compare specs, generate diff reports, and optimize code reuse across variants.
*   **TypeScript Support**: First-class TypeScript support via `genType`. Exported functions and types are idiomatic and fully typed for use in TypeScript projects.

## 📦 Installation

```bash
npm install @f3liz/rescript-autogen-openapi sury
```

**Important**: This library has a peer dependency on `sury` (ReScript Schema). You must install it in your project because the generated code directly depends on it for runtime validation.

### Configure `rescript.json`

Add `sury` to your project dependencies:

```json
{
  "name": "my-project",
  "dependencies": ["sury"]
}
```

Ensure you have `rescript` (^12.0.0) installed.

## 🚀 Usage

### Library API

```javascript
import { generate } from '@f3liz/rescript-autogen-openapi';

const config = {
  specPath: 'https://misskey.io/api.json',
  outputDir: './src/generated',
  strategy: 'SharedBase', // 'SharedBase' or 'Separate'
  modulePerTag: true,
  targets: {
    rescriptApi: true,      // Core API
    rescriptWrapper: true,  // Pipe-first wrapper
    typescriptDts: true,    // TypeScript types
    typescriptWrapper: true // TypeScript client
  }
};

await generate(config);
```

### Configuration Options

```javascript
const config = {
  // Required
  specPath: 'https://example.com/api.json',  // URL or local file path
  outputDir: './generated',
  
  // Optional
  strategy: 'SharedBase',           // 'Separate' | 'SharedBase'
  modulePerTag: true,               // Generate one module per API tag
  generateDiffReport: true,         // Generate markdown diff reports
  breakingChangeHandling: 'Warn',   // 'Ignore' | 'Warn' | 'Error'
  includeTags: undefined,           // Filter to specific tags
  excludeTags: undefined,           // Exclude specific tags
  
  // Multi-fork configuration
  forkSpecs: [
    { name: 'cherrypick', specPath: 'https://kokonect.link/api.json' },
  ],
  
  // Output targets
  targets: {
    rescriptApi: true,
    rescriptWrapper: false,
    typescriptDts: false,
    typescriptWrapper: false,
  },

  // Documentation overrides
  generateDocOverrides: false,
  docOverrideDir: './docs/api-overrides',
};
```

## 📚 Examples

Detailed examples are available in the `examples/` directory:

*   **01-generate-single-spec.mjs**: Basic generation from one API spec.
*   **02-compare-specs.mjs**: Generate a difference report between two specs.
*   **03-generate-multi-fork.mjs**: Advanced usage for multiple API forks with code sharing.

## 🛠️ Development

```bash
npm install
npm run build
npm test
```

## 📄 License

This project is licensed under the [Mozilla Public License 2.0](LICENSE).
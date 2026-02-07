#!/usr/bin/env node
// refresh-docs.mjs - Refresh documentation override files
// This script updates markdown files with new hashes while preserving overrides

import { generate } from './lib/es6/src/Codegen.mjs';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';

const HELP_TEXT = `
Documentation Override Refresh Tool

Usage:
  node refresh-docs.mjs [options]

Options:
  --spec <path>          Path or URL to OpenAPI spec (required)
  --docs-dir <path>      Directory containing override files (required)
  --mode <mode>          Refresh mode (default: invalid)
                         - all: Refresh all files, update hashes
                         - empty: Only refresh files without overrides
                         - invalid: Only refresh files with hash mismatches
  --host <url>           API host URL
  --help                 Show this help message

Modes:
  all       - Updates all markdown files with new hashes
              Preserves all custom overrides
              Use when API spec has many changes
  
  empty     - Only updates files that have no custom documentation
              Files with overrides are left unchanged
              Use for new endpoints or after adding custom docs
  
  invalid   - Only updates files where hash doesn't match current endpoint
              Preserves custom documentation but updates metadata
              Use after API updates to fix mismatches (RECOMMENDED)

Examples:
  # Refresh only files with hash mismatches (recommended)
  node refresh-docs.mjs --spec https://api.example.com/openapi.json --docs-dir ./docs

  # Refresh all files
  node refresh-docs.mjs --spec ./openapi.json --docs-dir ./docs --mode all

  # Only refresh files without custom documentation
  node refresh-docs.mjs --spec ./openapi.json --docs-dir ./docs --mode empty

Notes:
  - Custom documentation in override blocks is always preserved
  - Hash mismatches will be reported as warnings during generation
  - Run this script after updating your API spec to sync documentation
`;

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    spec: null,
    docsDir: null,
    mode: 'invalid',
    host: null,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--help':
      case '-h':
        console.log(HELP_TEXT);
        process.exit(0);
        break;
      case '--spec':
        options.spec = args[++i];
        break;
      case '--docs-dir':
        options.docsDir = args[++i];
        break;
      case '--mode':
        options.mode = args[++i];
        break;
      case '--host':
        options.host = args[++i];
        break;
      default:
        console.error(`Unknown option: ${args[i]}`);
        console.log('Use --help for usage information');
        process.exit(1);
    }
  }

  // Validate required options
  if (!options.spec) {
    console.error('Error: --spec is required');
    console.log('Use --help for usage information');
    process.exit(1);
  }

  if (!options.docsDir) {
    console.error('Error: --docs-dir is required');
    console.log('Use --help for usage information');
    process.exit(1);
  }

  // Validate mode
  if (!['all', 'empty', 'invalid'].includes(options.mode)) {
    console.error(`Error: Invalid mode '${options.mode}'. Must be: all, empty, or invalid`);
    process.exit(1);
  }

  return options;
}

async function main() {
  const options = parseArgs();

  console.log('📝 Documentation Override Refresh Tool\n');
  console.log(`Spec: ${options.spec}`);
  console.log(`Docs Directory: ${options.docsDir}`);
  console.log(`Mode: ${options.mode}`);
  if (options.host) {
    console.log(`Host: ${options.host}`);
  }
  console.log();

  // Check if docs directory exists
  if (!existsSync(options.docsDir)) {
    console.error(`Error: Docs directory not found: ${options.docsDir}`);
    console.error('Run code generation with --generate-doc-overrides first');
    process.exit(1);
  }

  try {
    // Import the refresh function from ReScript
    const { refreshOverrideFiles, generateEndpointHash } = await import('./lib/es6/src/core/DocOverride.mjs');
    const { getAllEndpoints } = await import('./lib/es6/src/core/OpenAPIParser.mjs');
    
    console.log('🔄 Loading OpenAPI spec...');
    
    // Load spec
    let spec;
    if (options.spec.startsWith('http://') || options.spec.startsWith('https://')) {
      const response = await fetch(options.spec);
      spec = await response.json();
    } else {
      const content = readFileSync(resolve(options.spec), 'utf8');
      spec = JSON.parse(content);
    }
    
    console.log(`✓ Loaded spec: ${spec.info.title} v${spec.info.version}\n`);
    
    // Get all endpoints
    const endpoints = getAllEndpoints(spec);
    console.log(`Found ${endpoints.length} endpoints\n`);
    
    // Map mode to ReScript enum
    const modeMap = {
      'all': { TAG: 'RefreshAll' },
      'empty': { TAG: 'RefreshEmptyOnly' },
      'invalid': { TAG: 'RefreshInvalid' },
    };
    
    console.log(`🔄 Refreshing documentation files (mode: ${options.mode})...\n`);
    
    // Refresh override files
    const result = refreshOverrideFiles(
      spec,
      endpoints,
      resolve(options.docsDir, '..'), // Parent of docs dir
      modeMap[options.mode],
      options.host || undefined
    );
    
    // Check result
    if (result.TAG === 'Ok') {
      const refreshed = result._0;
      console.log(`✅ Successfully refreshed ${refreshed.length} file(s)\n`);
      
      if (refreshed.length > 0) {
        console.log('Refreshed files:');
        refreshed.forEach(file => {
          console.log(`  ✓ ${file}`);
        });
      } else {
        console.log('No files needed refreshing.');
      }
      
      console.log('\n💡 Next steps:');
      console.log('1. Review the updated markdown files');
      console.log('2. Add custom documentation in override blocks');
      console.log('3. Regenerate code with your overrides');
    } else {
      const errors = result._0;
      console.error(`❌ Failed to refresh ${errors.length} file(s)\n`);
      
      console.error('Errors:');
      errors.forEach(err => {
        console.error(`  ✗ ${err}`);
      });
      
      process.exit(1);
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('💥 Fatal error:', err);
  process.exit(1);
});

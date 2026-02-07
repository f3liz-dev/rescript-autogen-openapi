#!/usr/bin/env node
// Example 2: Compare two OpenAPI specs
//
// This example demonstrates:
// - Comparing two versions of an API
// - Detecting added endpoints and modified schemas
// - Generating a markdown diff report

import { compareSpecs } from '../lib/es6/src/Codegen.mjs';
import * as SchemaRefResolver from '../lib/es6/src/core/SchemaRefResolver.mjs';
import { mkdirSync, existsSync, rmSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function main() {
  console.log('🔍 Example 2: Compare Petstore vs Petstore Extended\n');
  
  const baseSpecPath = join(__dirname, 'fixtures/petstore.json');
  const forkSpecPath = join(__dirname, 'fixtures/petstore-extended.json');
  const outputDir = join(__dirname, 'comparison');
  const reportPath = join(outputDir, 'petstore-diff.md');

  if (!existsSync(outputDir)) {
    mkdirSync(outputDir, { recursive: true });
  }

  console.log('📡 Resolving specs...');
  const baseResult = await SchemaRefResolver.resolve(baseSpecPath);
  const forkResult = await SchemaRefResolver.resolve(forkSpecPath);

  if (baseResult.TAG === 'Ok' && forkResult.TAG === 'Ok') {
    const baseSpec = baseResult._0;
    const forkSpec = forkResult._0;

    console.log('🔄 Comparing APIs...');
    const diff = await compareSpecs(
      baseSpec,
      forkSpec,
      'petstore',
      'petstore-extended',
      reportPath
    );

    console.log('✅ Comparison complete!\n');
    console.log(`📈 Summary:`);
    console.log(`   Added endpoints:    ${diff.addedEndpoints.length}`);
    console.log(`   Removed endpoints:  ${diff.removedEndpoints.length}`);
    console.log(`   Modified endpoints: ${diff.modifiedEndpoints.length}`);
    console.log(`   Added schemas:      ${diff.addedSchemas.length}`);
    console.log(`   Modified schemas:   ${diff.modifiedSchemas.length}`);

    console.log(`\n📄 Detailed report saved to:`);
    console.log(`   ${reportPath.replace(process.cwd(), '.')}`);
  } else {
    console.error('❌ Failed to resolve specs');
    process.exit(1);
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
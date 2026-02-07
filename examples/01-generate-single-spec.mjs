#!/usr/bin/env node
// Example 1: Generate type-safe API client from a local OpenAPI spec
//
// This example demonstrates:
// - Parsing a local OpenAPI 3.1 spec
// - Generating ReScript types and Sury validation schemas
// - Creating per-tag modules

import { generateFromFile } from '../lib/es6/src/Codegen.mjs';
import { mkdirSync, existsSync, rmSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function main() {
  console.log('📦 Example 1: Generate from Single OpenAPI Spec\n');
  
  const outputDir = join(__dirname, 'single-spec/generated');
  const specPath = join(__dirname, 'fixtures/petstore.json');

  // Clean and create output directory
  if (existsSync(outputDir)) {
    rmSync(outputDir, { recursive: true });
  }
  mkdirSync(outputDir, { recursive: true });
  
  console.log(`📡 Reading spec from ${specPath}...`);
  
  const result = await generateFromFile(
    specPath,
    outputDir,
    {
      outputDir,
      strategy: 'Separate',
      modulePerTag: true,
    }
  );
  
  if (result.TAG === 'Ok') {
    const { generatedFiles } = result._0;
    
    console.log('✅ Code generation complete!\n');
    console.log(`📁 Generated ${generatedFiles.length} files:`);
    
    generatedFiles.forEach(file => {
      console.log(`   - ${file.replace(process.cwd(), '.')}`);
    });
    
    console.log('\n💡 What was generated:');
    console.log('   • ReScript types for Pet schema');
    console.log('   • Sury validation schemas');
    console.log('   • Pets.res module with list and create endpoints');
    
  } else {
    console.error('❌ Generation failed:', result._0);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
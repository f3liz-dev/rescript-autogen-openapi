#!/usr/bin/env node
// Example 3: Generate shared base + fork-specific extensions
//
// This example demonstrates the multi-fork feature:
// - Extracting code shared between two API versions
// - Generating fork-specific extensions
// - Maximizing code reuse

import { generateFromFile } from '../lib/es6/src/Codegen.mjs';
import { mkdirSync, existsSync, rmSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function main() {
  console.log('🌳 Example 3: Generate Shared Base + Fork Extensions\n');
  
  const outputDir = join(__dirname, 'multi-fork/generated');
  const baseSpecPath = join(__dirname, 'fixtures/petstore.json');
  const extendedSpecPath = join(__dirname, 'fixtures/petstore-extended.json');

  if (existsSync(outputDir)) {
    rmSync(outputDir, { recursive: true });
  }
  mkdirSync(outputDir, { recursive: true });
  
  console.log('📡 Processing specs...');
  
  const result = await generateFromFile(
    baseSpecPath,
    outputDir,
    {
      outputDir,
      strategy: 'SharedBase',
      modulePerTag: true,
      generateDiffReport: true,
      baseInstanceName: 'petstore-base', // Required for SharedBase strategy
      forkSpecs: [
        {
          name: 'extended',
          specPath: extendedSpecPath,
        },
      ],
    }
  );
  
  if (result.TAG === 'Ok') {
    const { generatedFiles } = result._0;
    
    console.log('✅ Multi-fork code generation complete!\n');
    console.log(`📁 Generated ${generatedFiles.length} files\n`);
    
    console.log('📊 What was generated:');
    console.log('1. Petstore-base/ - Shared code for common endpoints');
    console.log('2. extended/ - Extension code for unique "store" endpoints');
    console.log('3. Reports - Diff and merge stats\n');
    
    generatedFiles.forEach(file => {
      console.log(`   - ${file.replace(process.cwd(), '.')}`);
    });
    
  } else {
    console.error('❌ Generation failed:', result._0);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
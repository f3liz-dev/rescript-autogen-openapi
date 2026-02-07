#!/usr/bin/env node
// Quick test with local small spec

import { generateFromFile } from '../lib/es6/src/Codegen.mjs';
import { mkdirSync, existsSync, rmSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function main() {
  console.log('🧪 Quick test\n');
  
  const outputDir = join(__dirname, 'test-output');
  const specPath = join(__dirname, 'fixtures/petstore.json');

  if (existsSync(outputDir)) {
    rmSync(outputDir, { recursive: true });
  }
  mkdirSync(outputDir, { recursive: true });
  
  console.log('📡 Testing with local petstore spec...');
  
  const result = await generateFromFile(
    specPath,
    outputDir,
  );
  
  if (result.TAG === 'Ok') {
    const success = result._0;
    console.log('✅ Success!');
    console.log(`Generated ${success.generatedFiles.length} files:`);
    success.generatedFiles.forEach(f => console.log(`  - ${f.replace(process.cwd(), '.')}`));
    
    if (success.warnings && success.warnings.length > 0) {
      console.log(`\n⚠️  Warnings (${success.warnings.length}):`);
      success.warnings.slice(0, 5).forEach(w => {
        console.log(`  - ${w.TAG}`);
      });
    } else {
      console.log('No warnings!');
    }
  } else {
    const error = result._0;
    console.error('❌ Failed!');
    console.error('Error type:', error.TAG);
    console.error('Details:', JSON.stringify(error, null, 2));
  }
}

main().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});
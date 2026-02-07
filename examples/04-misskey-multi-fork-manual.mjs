#!/usr/bin/env node
// Example 4: Real-world multi-fork generation (Misskey + Cherrypick)
//
// This example demonstrates the full power of the codegen on real-world specs:
// - Extracts shared code between Misskey.io and Kokonect.link (Cherrypick)
// - Handles 400+ endpoints and complex schemas
// - Generates diff and merge reports

import { generateFromUrl } from '../lib/es6/src/Codegen.mjs';
import { mkdirSync, existsSync, rmSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function main() {
  console.log('🌳 Example 4: Real-World Multi-Fork (Misskey & Cherrypick)\n');
  
  const outputDir = join(__dirname, 'multi-fork/misskey-generated');

  if (existsSync(outputDir)) {
    rmSync(outputDir, { recursive: true });
  }
  mkdirSync(outputDir, { recursive: true });
  
  console.log('📡 Fetching real-world specs (this may take a minute)...');
  console.log('   • Misskey.io (base)');
  console.log('   • Kokonect.link (Cherrypick fork)');
  
  const result = await generateFromUrl(
    'https://misskey.io/api.json',
    outputDir,
    {
      outputDir,
      strategy: 'SharedBase',
      modulePerTag: true,
      generateDiffReport: true,
      baseInstanceName: 'misskey',
      baseModulePrefix: 'Misskey',
      forkSpecs: [
        {
          name: 'cherrypick',
          specPath: 'https://kokonect.link/api.json',
        },
      ],
    }
  );
  
  if (result.TAG === 'Ok') {
    const { generatedFiles } = result._0;
    
    console.log('\n✅ Real-world generation complete!');
    console.log(`📁 Generated ${generatedFiles.length} files in:`);
    console.log(`   ${outputDir.replace(process.cwd(), '.')}\n`);
    
    console.log('📊 Key highlights:');
    console.log('   - Shared endpoints extracted to misskey/api/');
    console.log('   - Cherrypick-specific endpoints in cherrypick/api/');
    console.log('   - Diff reports generated for both forks');
    
  } else {
    console.error('\n❌ Generation failed:', result._0);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('\n💥 Error:', err);
  process.exit(1);
});
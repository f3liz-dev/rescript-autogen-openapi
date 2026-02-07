// Test script to parse local and real-world Misskey/Cherrypick APIs
import { resolve } from '../lib/es6/src/core/SchemaRefResolver.mjs';
import { getAllEndpoints, getAllTags } from '../lib/es6/src/core/OpenAPIParser.mjs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function testUrl(name, url) {
  console.log(`📡 Fetching ${name} spec from ${url}...`);
  try {
    const result = await resolve(url, 120000);
    if (result.TAG === 'Ok') {
      const spec = result._0;
      console.log(`✅ ${name} API v${spec.info.version}`);
      const endpoints = getAllEndpoints(spec);
      console.log(`   Total endpoints: ${endpoints.length}`);
      return true;
    } else {
      console.error(`❌ Failed to parse ${name}:`, result._0);
      return false;
    }
  } catch (err) {
    console.error(`💥 Error fetching ${name}:`, err.message);
    return false;
  }
}

async function testParser() {
  console.log('🧪 Testing OpenAPI Parser\n');
  
  // 1. Local Fixtures (Fast)
  console.log('--- Local Fixtures ---');
  const petstorePath = join(__dirname, 'fixtures/petstore.json');
  const petstoreResult = await resolve(petstorePath);
  if (petstoreResult.TAG === 'Ok') {
    const spec = petstoreResult._0;
    console.log(`✅ Petstore API v${spec.info.version} (Local)`);
    console.log(`   Total endpoints: ${getAllEndpoints(spec).length}`);
  }

  console.log('\n--- Real World APIs (Slow) ---');
  
  // 2. Misskey.io
  await testUrl('Misskey.io', 'https://misskey.io/api.json');
  
  console.log('');
  
  // 3. Cherrypick (Kokonect.link)
  await testUrl('Cherrypick', 'https://kokonect.link/api.json');
  
  console.log('\n✨ Parser tests complete!');
}

testParser().catch(err => {
  console.error('💥 Error:', err);
  process.exit(1);
});

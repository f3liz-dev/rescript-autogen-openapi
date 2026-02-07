import test from 'node:test';
import assert from 'node:assert/strict';
import { resolve } from '../lib/es6/src/core/SchemaRefResolver.mjs';
import { compareSpecs, generateFromFile, generateFromUrl } from '../lib/es6/src/Codegen.mjs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { existsSync, rmSync, mkdirSync } from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');
const fixturesDir = join(rootDir, 'examples/fixtures');
const testOutputDir = join(__dirname, 'output');

const petstorePath = join(fixturesDir, 'petstore.json');
const extendedPath = join(fixturesDir, 'petstore-extended.json');

test('Codegen Integration', async (t) => {
  // Setup output dir
  if (existsSync(testOutputDir)) {
    rmSync(testOutputDir, { recursive: true });
  }
  mkdirSync(testOutputDir, { recursive: true });

  await t.test('Diff Mode: compareSpecs should detect differences', async () => {
    const baseSpec = (await resolve(petstorePath))._0;
    const forkSpec = (await resolve(extendedPath))._0;
    
    const diff = await compareSpecs(baseSpec, forkSpec, 'base', 'extended');
    
    assert.equal(diff.addedEndpoints.length, 1);
    assert.equal(diff.modifiedSchemas.length, 1);
  });

  await t.test('Multi-Fork Mode: SharedBase strategy with fixtures', async () => {
    const outputDir = join(testOutputDir, 'multi-fork-fixtures');
    
    const result = await generateFromFile(
      petstorePath,
      outputDir,
      {
        outputDir,
        strategy: 'SharedBase',
        baseInstanceName: 'petstore-base',
        generateDiffReport: true,
        forkSpecs: [
          {
            name: 'extended',
            specPath: extendedPath,
          }
        ]
      }
    );

    assert.equal(result.TAG, 'Ok');
    assert.ok(existsSync(join(outputDir, 'petstore-base/api/PetstoreBasePets.res')));
    assert.ok(existsSync(join(outputDir, 'extended/api/ExtendedStore.res')));
  });
});
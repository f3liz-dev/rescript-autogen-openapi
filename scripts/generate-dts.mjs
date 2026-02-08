import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync, unlinkSync, renameSync } from 'fs';
import { join, dirname, relative, basename } from 'path';
import { execSync } from 'child_process';

const srcDir = 'src';
const destDir = 'lib/es6/src';

function getAllFiles(dirPath, arrayOfFiles) {
  const files = readdirSync(dirPath);
  arrayOfFiles = arrayOfFiles || [];

  files.forEach(function(file) {
    if (statSync(dirPath + "/" + file).isDirectory()) {
      arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles);
    } else {
      arrayOfFiles.push(join(dirPath, "/", file));
    }
  });

  return arrayOfFiles;
}

const allFiles = getAllFiles(srcDir);
const genFiles = allFiles.filter(f => f.endsWith('.gen.ts'));

let tempFiles = [];

try {
  // 1. First, prepare ALL temporary .ts files so they can resolve each other
  tempFiles = genFiles.map(file => {
    const baseName = basename(file, '.gen.ts');
    const dirName = dirname(file);
    const tempTsFile = join(dirName, `${baseName}.ts`);
    
    let content = readFileSync(file, 'utf8');
    
    // Fix imports in the content to point to other temporary .ts files
    content = content.replace(/\.gen'/g, "'");
    content = content.replace(/\.gen"/g, '"');
    content = content.replace(/from '\.\.\/src\//g, "from './");

    // Fix duplicate identifiers in Types.ts
    if (file.endsWith('Types.gen.ts')) {
       // Remove everything from "export type CodegenError_context = {" to the end if it's a duplicate
       // A more robust way: find the first occurrence and remove subsequent ones
       const parts = content.split('export type CodegenError_context =');
       if (parts.length > 2) {
           content = parts[0] + 'export type CodegenError_context =' + parts[1];
       }
       
       const parts2 = content.split('export type CodegenError_t =');
       if (parts2.length > 2) {
           content = parts2[0] + 'export type CodegenError_t =' + parts2[1];
       }
    }

    // To fix "Cannot find module './Codegen.mjs'", we can provide a dummy .d.ts or just ignore it in tsc
    content = content.replace(/import \* as (\w+) from '\.\/(\w+)\.mjs'/g, "// @ts-ignore\nimport * as $1 from './$2.mjs'");

    writeFileSync(tempTsFile, content);
    return { original: file, temp: tempTsFile, baseName, dirName };
  });

  // 2. Run tsc on all files at once for better resolution
  const tempPaths = tempFiles.map(f => f.temp).join(' ');
  if (tempPaths) {
    console.log(`Generating declarations for all files...`);
    // Use --noEmitOnError false to try to get declarations even if there are some minor errors
    try {
      execSync(`npx tsc --declaration --emitDeclarationOnly --isolatedModules --skipLibCheck --module esnext --target esnext --moduleResolution node --allowJs ${tempPaths}`, { stdio: 'inherit' });
    } catch (err) {
      console.warn(`tsc finished with some errors, but we will try to move generated declarations.`);
    }

    // 3. Move generated .d.ts files
    tempFiles.forEach(f => {
      const generatedDts = join(f.dirName, `${f.baseName}.d.ts`);
      if (existsSync(generatedDts)) {
        const destPath = join(destDir, relative(srcDir, generatedDts));
        const destDirPath = dirname(destPath);
        
        if (!existsSync(destDirPath)) {
          mkdirSync(destDirPath, { recursive: true });
        }
        
        renameSync(generatedDts, destPath);
        console.log(`Created: ${destPath}`);
      } else {
          console.warn(`Warning: ${generatedDts} was not generated.`);
      }
    });
  }
} catch (err) {
  console.error(`Failed during declaration generation:`, err.message);
} finally {
  // 4. Cleanup
  console.log('Cleaning up intermediate files...');
  tempFiles.forEach(f => {
    if (existsSync(f.temp)) unlinkSync(f.temp);
    if (existsSync(f.original)) unlinkSync(f.original);
  });

  // Also cleanup any .gen.ts in src or destDir that might have been missed or copied by ReScript
  const cleanupGenFiles = (dir) => {
    if (existsSync(dir)) {
      getAllFiles(dir).filter(f => f.endsWith('.gen.ts')).forEach(f => {
        try {
          unlinkSync(f);
          console.log(`Removed: ${f}`);
        } catch (e) {
          // Ignore errors during cleanup
        }
      });
    }
  };

  cleanupGenFiles(srcDir);
  cleanupGenFiles(destDir);
}

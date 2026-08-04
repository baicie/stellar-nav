import { readdir, readFile } from 'node:fs/promises';
import { extname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const coreDirectory = fileURLToPath(new URL('../src/core/', import.meta.url));
const forbiddenImports = [
  /^expo(?:-|$)/,
  /^react$/,
  /^react-native(?:-|$)/,
  /^@shopify\/react-native-skia$/,
  /^zustand$/,
];

async function collectSourceFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const nestedFiles = await Promise.all(
    entries.map((entry) => {
      const path = join(directory, entry.name);
      return entry.isDirectory() ? collectSourceFiles(path) : [path];
    }),
  );

  return nestedFiles.flat().filter((path) => ['.ts', '.tsx'].includes(extname(path)));
}

const sourceFiles = await collectSourceFiles(coreDirectory);
const violations = [];

for (const file of sourceFiles) {
  const source = await readFile(file, 'utf8');
  const imports = source.matchAll(/(?:from\s+|import\s*\()["']([^"']+)["']/g);

  for (const match of imports) {
    const dependency = match[1];
    if (dependency && forbiddenImports.some((pattern) => pattern.test(dependency))) {
      violations.push(`${relative(process.cwd(), file)} imports ${dependency}`);
    }
  }
}

if (violations.length > 0) {
  console.error(`Core boundary violations:\n${violations.join('\n')}`);
  process.exitCode = 1;
} else {
  console.log(`Core boundary verified across ${sourceFiles.length} source files.`);
}

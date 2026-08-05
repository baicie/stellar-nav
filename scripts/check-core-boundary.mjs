import { readdir, readFile } from 'node:fs/promises';
import { dirname, extname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const sourceDirectory = fileURLToPath(new URL('../src/', import.meta.url));
const forbiddenImports = [
  /^expo(?:-|$)/,
  /^react$/,
  /^react-native(?:-|$)/,
  /^@shopify\/react-native-skia$/,
  /^zustand$/,
];
const forbiddenLayerDependencies = {
  core: new Set(['app', 'components', 'data', 'design', 'renderer']),
  data: new Set(['app', 'components', 'design', 'renderer']),
  renderer: new Set(['app', 'components', 'data']),
  components: new Set(['app']),
};

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

const sourceFiles = await collectSourceFiles(sourceDirectory);
const violations = [];

for (const file of sourceFiles) {
  const sourceLayer = relative(sourceDirectory, file).split(sep)[0];
  const source = await readFile(file, 'utf8');
  const imports = source.matchAll(/(?:from\s+|import\s*\()["']([^"']+)["']/g);

  for (const match of imports) {
    const dependency = match[1];
    if (
      sourceLayer === 'core' &&
      dependency &&
      forbiddenImports.some((pattern) => pattern.test(dependency))
    ) {
      violations.push(`${relative(process.cwd(), file)} imports ${dependency}`);
    }

    if (!dependency?.startsWith('.')) {
      continue;
    }

    const target = resolve(dirname(file), dependency);
    const targetRelativePath = relative(sourceDirectory, target);
    const targetLayer = targetRelativePath.split(sep)[0];
    const forbiddenTargets = forbiddenLayerDependencies[sourceLayer];

    if (targetRelativePath.startsWith('..') || forbiddenTargets?.has(targetLayer)) {
      violations.push(
        `${relative(process.cwd(), file)} crosses from ${sourceLayer} to ${targetRelativePath.startsWith('..') ? 'outside src' : targetLayer}`,
      );
    }
  }
}

if (violations.length > 0) {
  console.error(`Source boundary violations:\n${violations.join('\n')}`);
  process.exitCode = 1;
} else {
  console.log(`Source boundaries verified across ${sourceFiles.length} source files.`);
}

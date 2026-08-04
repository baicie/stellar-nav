import { readFile, readdir, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gzipSync } from 'node:zlib';

const outputDirectory = fileURLToPath(new URL('../dist/', import.meta.url));
const maximumCompressedJavaScriptBytes = 1_400_000;

async function collectFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(
    entries.map((entry) => {
      const path = join(directory, entry.name);
      return entry.isDirectory() ? collectFiles(path) : [path];
    }),
  );

  return files.flat();
}

const files = await collectFiles(outputDirectory);
const javaScriptFiles = files.filter((file) => file.endsWith('.js'));
let compressedJavaScriptBytes = 0;

for (const file of javaScriptFiles) {
  compressedJavaScriptBytes += gzipSync(await readFile(file)).byteLength;
}

const totalBytes = (await Promise.all(files.map(async (file) => (await stat(file)).size))).reduce(
  (total, size) => total + size,
  0,
);

console.log(
  `Web export: ${files.length} files, ${(totalBytes / 1_000_000).toFixed(2)} MB raw, ` +
    `${(compressedJavaScriptBytes / 1_000).toFixed(0)} kB compressed JavaScript.`,
);

if (compressedJavaScriptBytes > maximumCompressedJavaScriptBytes) {
  console.error(
    `Compressed JavaScript exceeds ${(maximumCompressedJavaScriptBytes / 1_000).toFixed(0)} kB budget.`,
  );
  process.exitCode = 1;
}

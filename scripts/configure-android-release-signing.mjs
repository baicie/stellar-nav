import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import { configureAndroidAbiSplits, configureAndroidReleaseSigning } from './release-config.mjs';

const buildGradlePath = resolve(process.argv[2] ?? 'android/app/build.gradle');
const source = await readFile(buildGradlePath, 'utf8');
const configured = configureAndroidAbiSplits(configureAndroidReleaseSigning(source));

await writeFile(buildGradlePath, configured);
console.log(`Android release signing and ABI splits configured in ${buildGradlePath}.`);

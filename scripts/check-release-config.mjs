import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

import { validateReleaseMetadata } from './release-config.mjs';

const projectRoot = fileURLToPath(new URL('../', import.meta.url));
const packageJsonPath = new URL('../package.json', import.meta.url);
const appJsonPath = new URL('../app.json', import.meta.url);
const releaseManifestPath = new URL('../docs/releases/manifest.json', import.meta.url);

const [packageJson, appJson, releaseManifest] = await Promise.all(
  [packageJsonPath, appJsonPath, releaseManifestPath].map(async (path) =>
    JSON.parse(await readFile(path, 'utf8')),
  ),
);

const version = validateReleaseMetadata({
  packageVersion: packageJson.version,
  appVersion: appJson.expo.version,
  androidVersionCode: appJson.expo.android.versionCode,
  androidReleases: releaseManifest.android.releases,
  releaseVersion: process.env.RELEASE_VERSION,
});

console.log(
  `Release metadata verified for v${version} (Android versionCode ${appJson.expo.android.versionCode}) in ${projectRoot}.`,
);

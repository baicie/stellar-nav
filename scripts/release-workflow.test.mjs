import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import test from 'node:test';

const workflowPath = new URL('../.github/workflows/release.yml', import.meta.url);

test('Android release workflow keeps the ABI and immutable asset contract', async () => {
  const workflow = await readFile(workflowPath, 'utf8');

  assert.match(workflow, /:app:bundleRelease[\s\S]*-PstellarNav\.enableAbiSplits=false/);
  assert.match(workflow, /:app:assembleRelease[\s\S]*-PstellarNav\.enableAbiSplits=true/);
  assert.match(workflow, /-PreactNativeArchitectures=armeabi-v7a,arm64-v8a,x86_64/);
  assert.match(workflow, /bundletool-all-1\.18\.3\.jar/);
  assert.match(workflow, /a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29/);
  assert.match(workflow, /aab_abis/);
  assert.match(workflow, /aab_debug_symbol_abis/);
  assert.match(workflow, /versionCode/);
  assert.match(
    workflow,
    /This jar contains unsigned entries which have not been integrity-checked/,
  );
  assert.match(workflow, /cmp --silent/);
  assert.doesNotMatch(workflow, /gh release upload[\s\S]*--clobber/);

  for (const asset of [
    'stellar-nav-android-arm64-v8a.apk',
    'stellar-nav-android-armeabi-v7a.apk',
    'stellar-nav-android-x86_64.apk',
    'stellar-nav-android.aab',
    'SHA256SUMS.txt',
  ]) {
    assert.match(workflow, new RegExp(asset.replaceAll('.', '\\.'), 'g'));
  }
});

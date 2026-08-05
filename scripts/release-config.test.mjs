import assert from 'node:assert/strict';
import test from 'node:test';

import {
  configureAndroidReleaseSigning,
  normalizeCertificateSha256,
  normalizeReleaseVersion,
  validateAndroidReleaseHistory,
  validateReleaseMetadata,
} from './release-config.mjs';

const expoBuildGradleFixture = `android {
    signingConfigs {
        debug {
            storeFile file('debug.keystore')
        }
    }
    buildTypes {
        debug {
            signingConfig signingConfigs.debug
        }
        release {
            signingConfig signingConfigs.debug
            minifyEnabled false
        }
    }
}
`;

test('normalizes stable release versions', () => {
  assert.equal(normalizeReleaseVersion('v0.0.1'), '0.0.1');
  assert.equal(normalizeReleaseVersion('12.3.4'), '12.3.4');
  assert.throws(() => normalizeReleaseVersion('v1.0.0-beta.1'), /stable MAJOR\.MINOR\.PATCH/);
});

test('requires package, app, and requested release versions to match', () => {
  const androidReleases = [
    {
      version: '0.0.1',
      versionCode: 1,
      certificateSha256:
        'D4:CC:2E:B0:73:4E:E8:38:FF:1E:0A:B3:69:EF:2A:64:B8:FA:89:C2:C3:AD:93:47:9F:47:86:9A:A6:D5:DA:18',
    },
  ];

  assert.equal(
    validateReleaseMetadata({
      packageVersion: '0.0.1',
      appVersion: '0.0.1',
      androidVersionCode: 1,
      androidReleases,
      releaseVersion: 'v0.0.1',
    }),
    '0.0.1',
  );
  assert.throws(
    () =>
      validateReleaseMetadata({
        packageVersion: '0.0.1',
        appVersion: '0.0.2',
        androidVersionCode: 1,
        androidReleases,
      }),
    /does not match/,
  );
  assert.throws(
    () =>
      validateReleaseMetadata({
        packageVersion: '0.0.1',
        appVersion: '0.0.1',
        androidVersionCode: 0,
        androidReleases,
      }),
    /positive integer/,
  );
  assert.throws(
    () =>
      validateReleaseMetadata({
        packageVersion: '0.0.2',
        appVersion: '0.0.2',
        androidVersionCode: 1,
        androidReleases,
      }),
    /latest Android release/,
  );
});

test('requires Android release history to increase monotonically', () => {
  const certificateSha256 =
    'D4:CC:2E:B0:73:4E:E8:38:FF:1E:0A:B3:69:EF:2A:64:B8:FA:89:C2:C3:AD:93:47:9F:47:86:9A:A6:D5:DA:18';

  assert.deepEqual(
    validateAndroidReleaseHistory([
      { version: '0.0.1', versionCode: 1, certificateSha256 },
      { version: '0.1.0', versionCode: 2, certificateSha256 },
    ]),
    {
      version: '0.1.0',
      versionCode: 2,
      certificateSha256: certificateSha256.replaceAll(':', ''),
    },
  );
  assert.throws(
    () =>
      validateAndroidReleaseHistory([
        { version: '0.0.1', versionCode: 1, certificateSha256 },
        { version: '0.0.2', versionCode: 1, certificateSha256 },
      ]),
    /versionCode must increase/,
  );
  assert.throws(
    () =>
      validateAndroidReleaseHistory([
        { version: '0.1.0', versionCode: 1, certificateSha256 },
        { version: '0.0.2', versionCode: 2, certificateSha256 },
      ]),
    /version must increase/,
  );
  assert.throws(
    () =>
      validateAndroidReleaseHistory([
        { version: '0.0.1', versionCode: 1, certificateSha256 },
        {
          version: '0.1.0',
          versionCode: 2,
          certificateSha256: 'AA'.repeat(32),
        },
      ]),
    /certificateSha256 must remain stable/,
  );
});

test('normalizes and validates Android certificate fingerprints', () => {
  assert.equal(
    normalizeCertificateSha256(
      'd4:cc:2e:b0:73:4e:e8:38:ff:1e:0a:b3:69:ef:2a:64:b8:fa:89:c2:c3:ad:93:47:9f:47:86:9a:a6:d5:da:18',
    ),
    'D4CC2EB0734EE838FF1E0AB369EF2A64B8FA89C2C3AD93479F47869AA6D5DA18',
  );
  assert.throws(() => normalizeCertificateSha256('not-a-certificate'), /SHA-256/);
});

test('replaces Expo debug signing only for the release build type', () => {
  const configured = configureAndroidReleaseSigning(expoBuildGradleFixture);

  assert.match(configured, /stellar-nav-release-signing/);
  assert.match(configured, /storeFile file\(STELLAR_NAV_UPLOAD_STORE_FILE\)/);
  assert.match(configured, /release \{\n\s+signingConfig signingConfigs\.release/);
  assert.match(configured, /debug \{\n\s+signingConfig signingConfigs\.debug/);
  assert.equal(configureAndroidReleaseSigning(configured), configured);
});

test('fails closed when the Expo Gradle template changes', () => {
  assert.throws(
    () => configureAndroidReleaseSigning('android { buildTypes { release {} } }'),
    /template changed/,
  );
  assert.throws(
    () => configureAndroidReleaseSigning(`android { ${'// stellar-nav-release-signing'} }`),
    /configuration is incomplete/,
  );
});

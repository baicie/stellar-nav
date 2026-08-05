import assert from 'node:assert/strict';
import test from 'node:test';

import {
  androidReleaseAbis,
  createAndroidReleaseArtifactPlan,
  configureAndroidAbiSplits,
  configureAndroidReleaseSigning,
  extractSingleCertificateSha256,
  normalizeCertificateSha256,
  normalizeReleaseVersion,
  validateAndroidReleaseHistory,
  validateReleaseMetadata,
} from './release-config.mjs';

const certificatePemFixture = `-----BEGIN CERTIFICATE-----
MIICvjCCAaYCCQDtR5T/Z7ujmzANBgkqhkiG9w0BAQsFADAhMR8wHQYDVQQDDBZT
dGVsbGFyIE5hdiBDSSBGaXh0dXJlMB4XDTI2MDgwNTA3MzU1NVoXDTM2MDgwMjA3
MzU1NVowITEfMB0GA1UEAwwWU3RlbGxhciBOYXYgQ0kgRml4dHVyZTCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBAOFvzOlw+i6KQe3hn8QN0kiE/bmtaPO9
F3xNLGjnK69fESyJMkv/L8FGEkPCVtS+x9g9qojCu2Y8XQSwdD7nOfy89QutChnI
f2KDH2k1IBsD0FcP15gt9gcIBq94Dff0GmB7HzBR2vvRF3H9x8dMpv8vtcEOf3yb
QSNLqHqbLmARDgqbgonOO8CGTgbcapRHkobHP9jcxO0/Vg3GoDa77ueSEG4LnYaH
cCodRTjieE/8j7hH+Xmav/5J2x3vxnf9wmfgI0SV9cA9Pk4U/FOSE/cz7aPMWD/R
qKmUVpIbqS5SU7duT+pxPDcVrzFwvMXmIpX3Bj3Doz4pwB6iq75wTrECAwEAATAN
BgkqhkiG9w0BAQsFAAOCAQEAY39+xI7Azn7kcRzk9VNHBx58dQHpI+Jsh2ILiMCG
thhDqKxCIwTG4yM50LH1t7/IOisISvpURTR0cOINH+hZ0rIWW1HoX9n3wvMQY/2W
kTCLk9ud2w87IVPbIph3vvOz7JgynjHsJu7xIoUWLf+TkHC6jFjXpGDynY6PPttQ
dpti6GH/Pk6Xuu3ucheMVV+3Ybw109rHuQJrBSEb5iJzCGAtekm3ADzCAGUSLaWE
URr8GoQ37NQTiUV9JGY48vkgn32ZU7rj+5q0OkDlgeQsqloZsjRvjMDG3X1pBB57
JFRDWM5E6CMNn7eiiLmAMrAzFaSsR8SreW02K+3iRv+b8w==
-----END CERTIFICATE-----`;

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

test('extracts exactly one certificate fingerprint from apksigner PEM output', () => {
  const output = `Verified using v3 scheme (APK Signature Scheme v3): true\n${certificatePemFixture}\nSigner output complete`;

  assert.equal(
    extractSingleCertificateSha256(output),
    '2854EEF761FF49240742D302E2EFF8FC7552791FE364CB555657E631B56DE2F6',
  );
  assert.throws(() => extractSingleCertificateSha256('no certificate'), /exactly one/);
  assert.throws(
    () => extractSingleCertificateSha256(`${certificatePemFixture}\n${certificatePemFixture}`),
    /exactly one/,
  );
});

test('replaces Expo debug signing only for the release build type', () => {
  const configured = configureAndroidReleaseSigning(expoBuildGradleFixture);

  assert.match(configured, /stellar-nav-release-signing/);
  assert.match(configured, /storeFile file\(STELLAR_NAV_UPLOAD_STORE_FILE\)/);
  assert.match(configured, /release \{\n\s+signingConfig signingConfigs\.release/);
  assert.match(configured, /debug \{\n\s+signingConfig signingConfigs\.debug/);
  assert.equal(configureAndroidReleaseSigning(configured), configured);
});

test('configures exactly the supported ABI split APKs without a universal APK', () => {
  assert.deepEqual(androidReleaseAbis, ['arm64-v8a', 'armeabi-v7a', 'x86_64']);

  const configured = configureAndroidAbiSplits(expoBuildGradleFixture);

  assert.match(configured, /stellar-nav-abi-splits/);
  assert.match(
    configured,
    /enable \(findProperty\('stellarNav\.enableAbiSplits'\) \?: 'true'\)\.toBoolean\(\)/,
  );
  assert.match(configured, /include "arm64-v8a", "armeabi-v7a", "x86_64"/);
  assert.match(configured, /universalApk false/);
  assert.doesNotMatch(configured, /include .*\bx86\b/);
  assert.equal(configureAndroidAbiSplits(configured), configured);
});

test('plans stable Android release artifact names and generated paths', () => {
  assert.deepEqual(createAndroidReleaseArtifactPlan(), {
    apks: [
      {
        abi: 'arm64-v8a',
        source: 'android/app/build/outputs/apk/release/app-arm64-v8a-release.apk',
        target: 'stellar-nav-android-arm64-v8a.apk',
      },
      {
        abi: 'armeabi-v7a',
        source: 'android/app/build/outputs/apk/release/app-armeabi-v7a-release.apk',
        target: 'stellar-nav-android-armeabi-v7a.apk',
      },
      {
        abi: 'x86_64',
        source: 'android/app/build/outputs/apk/release/app-x86_64-release.apk',
        target: 'stellar-nav-android-x86_64.apk',
      },
    ],
    aab: {
      source: 'android/app/build/outputs/bundle/release/app-release.aab',
      target: 'stellar-nav-android.aab',
    },
  });
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
  assert.throws(
    () =>
      configureAndroidAbiSplits(
        configureAndroidAbiSplits(expoBuildGradleFixture).replace('reset()', '/* reset removed */'),
      ),
    /configuration is incomplete/,
  );
  assert.throws(
    () => configureAndroidAbiSplits('android { buildTypes { release {} } }'),
    /template changed/,
  );
  assert.throws(
    () => configureAndroidAbiSplits(`${expoBuildGradleFixture}\n\tsplits {}`),
    /template changed/,
  );
});

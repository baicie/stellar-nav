import { X509Certificate } from 'node:crypto';

const stableVersionPattern = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const certificateSha256Pattern = /^[0-9A-F]{64}$/;
const certificatePemPattern = /-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g;
const signingMarker = '// stellar-nav-release-signing';

export function normalizeReleaseVersion(value) {
  const version = value.startsWith('v') ? value.slice(1) : value;

  if (!stableVersionPattern.test(version)) {
    throw new Error(`Release version must use stable MAJOR.MINOR.PATCH format: ${value}`);
  }

  return version;
}

export function normalizeCertificateSha256(value) {
  const fingerprint = value.replaceAll(':', '').toUpperCase();

  if (!certificateSha256Pattern.test(fingerprint)) {
    throw new Error(`Android certificate fingerprint must be a SHA-256 value: ${value}`);
  }

  return fingerprint;
}

export function extractSingleCertificateSha256(output) {
  const certificates = output.match(certificatePemPattern) ?? [];

  if (certificates.length !== 1) {
    throw new Error(
      `apksigner output must contain exactly one signing certificate; found ${certificates.length}.`,
    );
  }

  try {
    return normalizeCertificateSha256(new X509Certificate(certificates[0]).fingerprint256);
  } catch (error) {
    throw new Error('apksigner output contains an invalid X.509 certificate.', { cause: error });
  }
}

function compareStableVersions(left, right) {
  const leftParts = left.split('.').map(BigInt);
  const rightParts = right.split('.').map(BigInt);

  for (let index = 0; index < leftParts.length; index += 1) {
    if (leftParts[index] !== rightParts[index]) {
      return leftParts[index] < rightParts[index] ? -1 : 1;
    }
  }

  return 0;
}

export function validateAndroidReleaseHistory(releases) {
  if (!Array.isArray(releases) || releases.length === 0) {
    throw new Error('Android release history must contain at least one release.');
  }

  let previousRelease;
  const normalizedReleases = releases.map((release) => {
    const normalizedRelease = {
      version: normalizeReleaseVersion(release.version),
      versionCode: release.versionCode,
      certificateSha256: normalizeCertificateSha256(release.certificateSha256),
    };

    if (!Number.isInteger(normalizedRelease.versionCode) || normalizedRelease.versionCode < 1) {
      throw new Error(
        `Android release ${normalizedRelease.version} versionCode must be a positive integer.`,
      );
    }

    if (
      previousRelease &&
      compareStableVersions(normalizedRelease.version, previousRelease.version) <= 0
    ) {
      throw new Error(
        `Android release version must increase after ${previousRelease.version}: ${normalizedRelease.version}`,
      );
    }

    if (previousRelease && normalizedRelease.versionCode <= previousRelease.versionCode) {
      throw new Error(
        `Android versionCode must increase after ${previousRelease.versionCode}: ${normalizedRelease.versionCode}`,
      );
    }

    if (
      previousRelease &&
      normalizedRelease.certificateSha256 !== previousRelease.certificateSha256
    ) {
      throw new Error(
        'Android release certificateSha256 must remain stable; record a separate key migration decision before rotating it.',
      );
    }

    previousRelease = normalizedRelease;
    return normalizedRelease;
  });

  return normalizedReleases.at(-1);
}

export function validateReleaseMetadata({
  packageVersion,
  appVersion,
  androidVersionCode,
  androidReleases,
  releaseVersion,
}) {
  const normalizedPackageVersion = normalizeReleaseVersion(packageVersion);
  const normalizedAppVersion = normalizeReleaseVersion(appVersion);

  if (normalizedPackageVersion !== normalizedAppVersion) {
    throw new Error(
      `package.json version ${packageVersion} does not match app.json version ${appVersion}.`,
    );
  }

  if (!Number.isInteger(androidVersionCode) || androidVersionCode < 1) {
    throw new Error('app.json android.versionCode must be a positive integer.');
  }

  const latestAndroidRelease = validateAndroidReleaseHistory(androidReleases);
  if (
    latestAndroidRelease.version !== normalizedPackageVersion ||
    latestAndroidRelease.versionCode !== androidVersionCode
  ) {
    throw new Error(
      `Application v${normalizedPackageVersion} (${androidVersionCode}) does not match latest Android release v${latestAndroidRelease.version} (${latestAndroidRelease.versionCode}).`,
    );
  }

  if (releaseVersion !== undefined) {
    const normalizedReleaseVersion = normalizeReleaseVersion(releaseVersion);
    if (normalizedReleaseVersion !== normalizedPackageVersion) {
      throw new Error(
        `Release version ${releaseVersion} does not match application version ${packageVersion}.`,
      );
    }
  }

  return normalizedPackageVersion;
}

function findBlockEnd(source, blockStart) {
  const openingBrace = source.indexOf('{', blockStart);
  if (openingBrace === -1) {
    throw new Error('Android release build block has no opening brace.');
  }

  let depth = 0;
  for (let index = openingBrace; index < source.length; index += 1) {
    if (source[index] === '{') {
      depth += 1;
    } else if (source[index] === '}') {
      depth -= 1;
      if (depth === 0) {
        return index + 1;
      }
    }
  }

  throw new Error('Android release build block has no closing brace.');
}

export function configureAndroidReleaseSigning(source) {
  if (source.includes(signingMarker)) {
    if (!source.includes('signingConfig signingConfigs.release')) {
      throw new Error('Android release signing marker exists but configuration is incomplete.');
    }
    return source;
  }

  const signingAnchor = '    signingConfigs {\n        debug {';
  if (!source.includes(signingAnchor)) {
    throw new Error('Expo Android signingConfigs template changed; refusing an unsafe edit.');
  }

  const signingConfig = `    signingConfigs {
        ${signingMarker}
        release {
            if (!project.hasProperty('STELLAR_NAV_UPLOAD_STORE_FILE') ||
                !project.hasProperty('STELLAR_NAV_UPLOAD_KEY_ALIAS') ||
                !project.hasProperty('STELLAR_NAV_UPLOAD_STORE_PASSWORD') ||
                !project.hasProperty('STELLAR_NAV_UPLOAD_KEY_PASSWORD')) {
                throw new GradleException('Missing Android release signing properties.')
            }

            storeFile file(STELLAR_NAV_UPLOAD_STORE_FILE)
            storePassword STELLAR_NAV_UPLOAD_STORE_PASSWORD
            keyAlias STELLAR_NAV_UPLOAD_KEY_ALIAS
            keyPassword STELLAR_NAV_UPLOAD_KEY_PASSWORD
        }
        debug {`;
  let configured = source.replace(signingAnchor, signingConfig);

  const buildTypesStart = configured.indexOf('    buildTypes {');
  const releaseStart = configured.indexOf('        release {', buildTypesStart);
  if (buildTypesStart === -1 || releaseStart === -1) {
    throw new Error('Expo Android release build type was not found.');
  }

  const releaseEnd = findBlockEnd(configured, releaseStart);
  const releaseBlock = configured.slice(releaseStart, releaseEnd);
  const debugSigningLine = '            signingConfig signingConfigs.debug';
  if (!releaseBlock.includes(debugSigningLine)) {
    throw new Error('Expo Android release signing line changed; refusing an unsafe edit.');
  }

  const signedReleaseBlock = releaseBlock.replace(
    debugSigningLine,
    '            signingConfig signingConfigs.release',
  );
  configured = `${configured.slice(0, releaseStart)}${signedReleaseBlock}${configured.slice(releaseEnd)}`;

  return configured;
}

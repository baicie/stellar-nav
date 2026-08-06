import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigation_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const manifest =
      '{"schemaVersion":1,"catalogVersion":"test-v1",'
      '"engineVersion":"0.1.0","systemId":"sol","capabilities":[]}';

  test('bridge contract accepts matching versioned envelopes', () {
    final contract = BridgeContract.fromManifestPayload(manifest);
    const payload =
        '{"schemaVersion":1,"catalogVersion":"test-v1",'
        '"dayFromJ2000":42.0,"data":['
        '{"id":"source","label":"Source","url":"urn:test",'
        '"accessedAtUtc":"2026-08-05T00:00:00Z"}]}';

    final sources = contract.decodeList(
      payload,
      SourceRef.fromJson,
      expectedDayFromJ2000: 42.0,
    );

    expect(sources.single.id, 'source');
  });

  test('bridge contract only accepts schema 1 for the solar system', () {
    expect(
      () => BridgeContract.fromManifestPayload(
        '{"schemaVersion":2,"catalogVersion":"test-v1",'
        '"engineVersion":"0.1.0","systemId":"sol","capabilities":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => BridgeContract.fromManifestPayload(
        '{"schemaVersion":1.0,"catalogVersion":"test-v1",'
        '"engineVersion":"0.1.0","systemId":"sol","capabilities":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => BridgeContract.fromManifestPayload(
        '{"schemaVersion":1,"catalogVersion":"test-v1",'
        '"engineVersion":"0.1.0","systemId":"alpha-centauri",'
        '"capabilities":[]}',
      ),
      throwsFormatException,
    );
  });

  test('bridge contract rejects schema, catalog and request-time drift', () {
    final contract = BridgeContract.fromManifestPayload(manifest);

    expect(
      () => contract.decodeList<SourceRef>(
        '{"schemaVersion":2,"catalogVersion":"test-v1","data":[]}',
        SourceRef.fromJson,
      ),
      throwsFormatException,
    );
    expect(
      () => contract.decodeList<SourceRef>(
        '{"schemaVersion":1.0,"catalogVersion":"test-v1","data":[]}',
        SourceRef.fromJson,
      ),
      throwsFormatException,
    );
    expect(
      () => contract.decodeList<SourceRef>(
        '{"schemaVersion":1,"catalogVersion":"other","data":[]}',
        SourceRef.fromJson,
      ),
      throwsFormatException,
    );
    expect(
      () => contract.decodeList<SourceRef>(
        '{"schemaVersion":1,"catalogVersion":"test-v1",'
        '"dayFromJ2000":41.0,"data":[]}',
        SourceRef.fromJson,
        expectedDayFromJ2000: 42.0,
      ),
      throwsFormatException,
    );
    expect(
      () => contract.decodeList<SourceRef>(
        '{"schemaVersion":1,"catalogVersion":"test-v1","data":[]}',
        SourceRef.fromJson,
        expectedDayFromJ2000: 42.0,
      ),
      throwsFormatException,
    );
  });

  test('bridge contract tolerates insignificant request-time rounding', () {
    final contract = BridgeContract.fromManifestPayload(manifest);

    final sources = contract.decodeList<SourceRef>(
      '{"schemaVersion":1,"catalogVersion":"test-v1",'
      '"dayFromJ2000":42.0000000001,"data":[]}',
      SourceRef.fromJson,
      expectedDayFromJ2000: 42.0,
    );

    expect(sources, isEmpty);
  });
}

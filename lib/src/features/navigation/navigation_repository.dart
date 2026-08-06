import 'dart:convert';

import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/rust/api/engine.dart' as engine;

abstract interface class NavigationRepository {
  List<CelestialObject> loadCatalog();
  List<SourceRef> loadSources();
  List<CelestialObject> search(String query);
  List<ObjectPosition> positionsAt(double dayFromJ2000);
  List<RoutePlan> planRoutes({
    required String originId,
    required String destinationId,
    required double departureDayFromJ2000,
    required String vehicleId,
  });
}

class RustNavigationRepository implements NavigationRepository {
  RustNavigationRepository()
    : _contract = BridgeContract.fromManifestPayload(
        engine.engineManifestJson(),
      );

  final BridgeContract _contract;

  @override
  List<CelestialObject> loadCatalog() =>
      _contract.decodeList(engine.catalogJson(), CelestialObject.fromJson);

  @override
  List<SourceRef> loadSources() =>
      _contract.decodeList(engine.sourcesJson(), SourceRef.fromJson);

  @override
  List<CelestialObject> search(String query) => _contract.decodeList(
    engine.searchJson(query: query),
    CelestialObject.fromJson,
  );

  @override
  List<ObjectPosition> positionsAt(double dayFromJ2000) => _contract.decodeList(
    engine.positionsJson(dayFromJ2000: dayFromJ2000),
    ObjectPosition.fromJson,
    expectedDayFromJ2000: dayFromJ2000,
  );

  @override
  List<RoutePlan> planRoutes({
    required String originId,
    required String destinationId,
    required double departureDayFromJ2000,
    required String vehicleId,
  }) => _contract.decodeList(
    engine.planRoutesJson(
      originId: originId,
      destinationId: destinationId,
      departureDayFromJ2000: departureDayFromJ2000,
      vehicleId: vehicleId,
    ),
    RoutePlan.fromJson,
    expectedDayFromJ2000: departureDayFromJ2000,
  );
}

class BridgeContract {
  const BridgeContract._({
    required this.schemaVersion,
    required this.catalogVersion,
  });

  factory BridgeContract.fromManifestPayload(String payload) {
    final manifest = _decodeObject(payload, 'engine manifest');
    final schemaVersion = manifest['schemaVersion'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw FormatException('Unsupported bridge schemaVersion: $schemaVersion');
    }
    final systemId = manifest['systemId'];
    if (systemId != 'sol') {
      throw FormatException('Unsupported bridge systemId: $systemId');
    }
    final catalogVersion = manifest['catalogVersion'];
    if (catalogVersion is! String || catalogVersion.isEmpty) {
      throw const FormatException('Invalid bridge catalogVersion');
    }

    return BridgeContract._(
      schemaVersion: schemaVersion,
      catalogVersion: catalogVersion,
    );
  }

  static const double _dayTolerance = 1e-9;

  final int schemaVersion;
  final String catalogVersion;

  List<T> decodeList<T>(
    String payload,
    T Function(Map<String, dynamic>) decode, {
    double? expectedDayFromJ2000,
  }) {
    final envelope = _decodeObject(payload, 'engine envelope');
    final envelopeSchemaVersion = envelope['schemaVersion'];
    if (envelopeSchemaVersion is! int ||
        envelopeSchemaVersion != schemaVersion) {
      throw FormatException(
        'Bridge schemaVersion does not match manifest: '
        '$envelopeSchemaVersion',
      );
    }
    if (envelope['catalogVersion'] != catalogVersion) {
      throw FormatException(
        'Bridge catalogVersion does not match manifest: '
        '${envelope['catalogVersion']}',
      );
    }

    if (expectedDayFromJ2000 != null) {
      final responseDay = envelope['dayFromJ2000'];
      if (!expectedDayFromJ2000.isFinite ||
          responseDay is! num ||
          !responseDay.toDouble().isFinite ||
          (responseDay.toDouble() - expectedDayFromJ2000).abs() >
              _dayTolerance) {
        throw FormatException(
          'Bridge dayFromJ2000 does not match request: $responseDay',
        );
      }
    }

    final data = envelope['data'];
    if (data is! List<dynamic>) {
      throw const FormatException('Bridge envelope data must be a list');
    }
    return data
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Bridge list item must be an object');
          }
          return decode(item);
        })
        .toList(growable: false);
  }
}

Map<String, dynamic> _decodeObject(String payload, String label) {
  final Object? value;
  try {
    value = jsonDecode(payload);
  } on FormatException catch (error) {
    throw FormatException('Invalid $label JSON: ${error.message}');
  }
  if (value is! Map<String, dynamic>) {
    throw FormatException('$label must be a JSON object');
  }
  return value;
}

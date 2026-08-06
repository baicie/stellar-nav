import 'dart:io';

import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigation_repository.dart';
import 'package:astro_nav/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var initialized = false;
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(_hostLibraryPath()),
    );
    initialized = true;
  });
  tearDownAll(() {
    if (initialized) RustLib.dispose();
  });

  test('real Rust bridge loads the solar catalog and teaching routes', () {
    final repository = RustNavigationRepository();
    final catalog = repository.loadCatalog();
    final positions = repository.positionsAt(9710);
    final routes = repository.planRoutes(
      originId: 'sol/earth/iss',
      destinationId: 'sol/earth/moon/artemis-base',
      departureDayFromJ2000: 9710,
      vehicleId: 'aurora-demo',
    );

    expect(catalog, hasLength(16));
    expect(
      positions
          .singleWhere(
            (position) => position.id == 'sol/earth/moon/artemis-base',
          )
          .provenance
          .nature,
      DataNature.fictional,
    );
    expect(routes.map((route) => route.strategy).toSet(), {
      RouteStrategy.fastest,
      RouteStrategy.fuelEfficient,
      RouteStrategy.safest,
    });
  });
}

String _hostLibraryPath() {
  if (Platform.isMacOS) return 'native/target/debug/libastro_engine.dylib';
  if (Platform.isLinux) return 'native/target/debug/libastro_engine.so';
  if (Platform.isWindows) return r'native\target\debug\astro_engine.dll';
  throw UnsupportedError(
    'Rust bridge smoke test does not support ${Platform.operatingSystem}',
  );
}

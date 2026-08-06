import 'package:astro_nav/src/app/astro_nav_app.dart';
import 'package:astro_nav/src/features/navigation/navigation_repository.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:astro_nav/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(RustLib.init);
  tearDownAll(RustLib.dispose);

  testWidgets('starts the Rust-backed solar navigation experience', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationRepositoryProvider.overrideWithValue(
            RustNavigationRepository(),
          ),
        ],
        child: const AstroNavApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('天枢'), findsOneWidget);
    expect(find.text('国际空间站 → 阿尔忒弥斯月面基地'), findsOneWidget);
    expect(find.byKey(const Key('destination-search-field')), findsOneWidget);
  });
}

import 'package:astro_nav/src/app/astro_nav_app.dart';
import 'package:astro_nav/src/features/navigation/navigation_repository.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:astro_nav/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RustLib.init();
    runApp(
      ProviderScope(
        overrides: [
          navigationRepositoryProvider.overrideWithValue(
            RustNavigationRepository(),
          ),
        ],
        child: const AstroNavApp(),
      ),
    );
  } catch (error) {
    runApp(StartupErrorApp(error: error));
  }
}

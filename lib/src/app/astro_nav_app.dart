import 'package:astro_nav/src/design/app_theme.dart';
import 'package:astro_nav/src/features/navigation/navigator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const _appLocale = Locale('zh', 'CN');
const _supportedLocales = [_appLocale];

class AstroNavApp extends StatelessWidget {
  const AstroNavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '天枢导航',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: _appLocale,
      supportedLocales: _supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const NavigatorScreen(),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '天枢导航',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: _appLocale,
      supportedLocales: _supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.satellite_alt_outlined,
                      size: 42,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '星历引擎未能启动',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '请确认 Rust 原生库或 WebAssembly 数据包已完成构建。',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$error',
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

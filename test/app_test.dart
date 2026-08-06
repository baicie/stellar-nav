import 'package:astro_nav/src/app/astro_nav_app.dart';
import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:astro_nav/src/features/navigation/widgets/map_controls.dart';
import 'package:astro_nav/src/features/navigation/widgets/mission_hud.dart';
import 'package:astro_nav/src/features/navigation/widgets/solar_map.dart';
import 'package:astro_nav/src/features/navigation/navigator_screen.dart';
import 'package:astro_nav/src/widgets/provenance_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_navigation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens directly into the Chinese solar navigation map', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('天枢'), findsOneWidget);
    expect(find.text('国际空间站 → 阿尔忒弥斯月面基地'), findsOneWidget);
    expect(find.byKey(const Key('destination-search-field')), findsOneWidget);
    expect(find.byTooltip('图层'), findsOneWidget);
    expect(find.text('航线'), findsOneWidget);
    expect(find.text('太阳系'), findsOneWidget);
  });

  testWidgets('declares Simplified Chinese as the application locale', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 120));

    final context = tester.element(find.byType(NavigatorScreen));
    expect(Localizations.localeOf(context), const Locale('zh', 'CN'));
  });

  testWidgets('searches Mars, shows science facts and replans', (tester) async {
    await _setPhoneSize(tester);
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
        initialSimulationDayProvider.overrideWithValue(9710),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AstroNavApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const Key('destination-search-field')),
      '火星',
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('search-result-sol/mars')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-result-sol/mars')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('对象详情'), findsOneWidget);
    expect(find.text('平均半径'), findsOneWidget);
    expect(find.text('观测'), findsWidgets);
    expect(find.text('来源：NASA 测试数据源'), findsWidgets);

    await _scrollObjectDetailsUntilVisible(
      tester,
      find.byKey(const Key('set-destination-button')),
    );
    await tester.tap(find.byKey(const Key('set-destination-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(navigatorProvider).destinationId, 'sol/mars');
    expect(find.text('候选航线'), findsOneWidget);
  });

  testWidgets('a reachable detail can become the route origin', (tester) async {
    await _setPhoneSize(tester);
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
        initialSimulationDayProvider.overrideWithValue(9710),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AstroNavApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const Key('destination-search-field')),
      '火星',
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('search-result-sol/mars')));
    await tester.pump(const Duration(milliseconds: 100));
    await _scrollObjectDetailsUntilVisible(
      tester,
      find.byKey(const Key('set-origin-button')),
    );
    await tester.tap(find.byKey(const Key('set-origin-button')));
    await tester.pump(const Duration(milliseconds: 100));

    final state = container.read(navigatorProvider);
    expect(state.originId, 'sol/mars');
    expect(state.destinationId, 'sol/earth/moon/artemis-base');
    expect(find.text('候选航线'), findsOneWidget);
  });

  testWidgets(
    'switches route strategy and starts navigation without frame state',
    (tester) async {
      await _setPhoneSize(tester);
      final container = ProviderContainer(
        overrides: [
          navigationRepositoryProvider.overrideWithValue(
            FakeNavigationRepository(),
          ),
          initialSimulationDayProvider.overrideWithValue(9710),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AstroNavApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.byKey(const Key('open-routes-button')));
      await tester.tap(find.byKey(const Key('open-routes-button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('直达 · 无中继停靠'), findsOneWidget);
      expect(find.bySemanticsLabel('教学窗口质量'), findsOneWidget);
      expect(find.textContaining('距下一个模型最优时机'), findsOneWidget);
      expect(find.text('模拟'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('strategy-fastest')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        container.read(navigatorProvider).selectedStrategy,
        RouteStrategy.fastest,
      );
      expect(find.byType(ProvenanceBadge), findsNWidgets(2));

      await tester.ensureVisible(
        find.byKey(const Key('navigation-toggle-button')),
      );
      await tester.tap(find.byKey(const Key('navigation-toggle-button')));
      await tester.pump();
      expect(container.read(navigatorProvider).isNavigating, isTrue);
      expect(find.text('模拟导航 · 最快'), findsOneWidget);

      SolarMapPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(SolarMap),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as SolarMapPainter;
      expect(painter().routeProgress.value, 0);

      await tester.pump(const Duration(seconds: 8));
      expect(painter().routeProgress.value, closeTo(0.5, 0.02));

      await tester.pump(const Duration(seconds: 9));
      expect(painter().routeProgress.value, 1);

      await tester.tap(find.byKey(const Key('navigation-toggle-button')));
      await tester.pump();
      expect(painter().routeProgress.value, 0);
    },
  );

  testWidgets('layer and timeline tools expose accessible Chinese controls', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.bySemanticsLabel('图层'), findsOneWidget);
    await tester.tap(find.byTooltip('图层'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('地图图层'), findsOneWidget);
    expect(find.text('天体'), findsOneWidget);
    expect(find.byType(ProvenanceBadge), findsNothing);

    await tester.tap(find.byTooltip('时间轴'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('simulation-time-slider')), findsOneWidget);
    expect(find.text('现在'), findsOneWidget);
    expect(find.bySemanticsLabel('后退 30 天'), findsOneWidget);
    final slider = tester.widget<Slider>(
      find.byKey(const Key('simulation-time-slider')),
    );
    expect(
      slider.semanticFormatterCallback?.call(slider.value),
      startsWith('模拟日期 '),
    );
    expect(find.byType(ProvenanceBadge), findsNWidgets(2));
    semantics.dispose();
  });

  testWidgets('keeps a map-first compact layout on 320 by 568 screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byTooltip('聚焦当前航线'), findsOneWidget);
    expect(find.byTooltip('图层'), findsOneWidget);
    expect(find.byTooltip('时间轴'), findsOneWidget);
    expect(find.byTooltip('放大地图'), findsNothing);
    expect(find.byTooltip('缩小地图'), findsNothing);
    expect(find.byTooltip('重置视角'), findsNothing);
    expect(
      find.byKey(const Key('open-routes-button')).hitTestable(),
      findsOneWidget,
    );

    final panel = tester.getRect(
      find.byKey(const Key('mobile-navigation-panel')),
    );
    expect(panel.top, greaterThanOrEqualTo(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact object details keep science facts and actions reachable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_testApp());
      await tester.pump(const Duration(milliseconds: 120));

      await tester.enterText(
        find.byKey(const Key('destination-search-field')),
        '火星',
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('search-result-sol/mars')));
      await tester.pump(const Duration(milliseconds: 100));

      final firstFact = find.text('平均半径');
      expect(firstFact, findsOneWidget);
      await tester.ensureVisible(firstFact);
      await tester.pump();
      expect(firstFact.hitTestable(), findsOneWidget);

      final destinationButton = find.byKey(const Key('set-destination-button'));
      final detailsScrollable = find.descendant(
        of: find.byKey(const Key('object-details-scroll-view')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        destinationButton,
        150,
        scrollable: detailsScrollable,
      );
      await tester.pump();
      expect(destinationButton.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact simulation HUD stays clear of map tools', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_testApp());
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byKey(const Key('open-routes-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(
      find.byKey(const Key('navigation-toggle-button')),
    );
    await tester.tap(find.byKey(const Key('navigation-toggle-button')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester
          .getRect(find.byType(MissionHud))
          .overlaps(tester.getRect(find.byType(MapToolbar))),
      isFalse,
    );

    await tester.tap(find.text('太阳系'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byKey(const Key('mobile-navigation-panel'))).height,
      lessThanOrEqualTo(228),
    );
  });

  testWidgets('empty route results show an explicit unavailable state', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          EmptyRouteNavigationRepository(),
        ),
        initialSimulationDayProvider.overrideWithValue(9710),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AstroNavApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('当前教学模型尚未生成可用航线'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('open-routes-button')))
          .onPressed,
      isNull,
    );

    container.read(navigatorProvider.notifier).openPanel(NavigatorPanel.routes);
    await tester.pump();
    expect(find.text('当前教学模型尚未生成可用航线'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('navigation-toggle-button')),
          )
          .onPressed,
      isNull,
    );

    container
        .read(navigatorProvider.notifier)
        .openPanel(NavigatorPanel.timeline);
    await tester.pump();
    expect(find.text('当前教学模型尚未生成可用航线'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system reduced-motion preference stops ambient animation', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationRepositoryProvider.overrideWithValue(
            FakeNavigationRepository(),
          ),
          initialSimulationDayProvider.overrideWithValue(9710),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const NavigatorScreen(),
        ),
      ),
    );
    await tester.pump();

    final customPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(SolarMap),
        matching: find.byType(CustomPaint),
      ),
    );
    final painter = customPaint.painter! as SolarMapPainter;
    final initialValue = painter.ambientAnimation.value;

    await tester.pump(const Duration(seconds: 1));

    expect(painter.ambientAnimation.value, initialValue);
  });
}

Widget _testApp() => ProviderScope(
  overrides: [
    navigationRepositoryProvider.overrideWithValue(FakeNavigationRepository()),
    initialSimulationDayProvider.overrideWithValue(9710),
  ],
  child: const AstroNavApp(),
);

Future<void> _setPhoneSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _scrollObjectDetailsUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.descendant(
      of: find.byKey(const Key('object-details-scroll-view')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump();
}

class EmptyRouteNavigationRepository extends FakeNavigationRepository {
  @override
  List<RoutePlan> planRoutes({
    required String originId,
    required String destinationId,
    required double departureDayFromJ2000,
    required String vehicleId,
  }) => const [];
}

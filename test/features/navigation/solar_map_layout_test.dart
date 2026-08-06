import 'dart:math' as math;

import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:astro_nav/src/features/navigation/widgets/solar_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_navigation_repository.dart';

void main() {
  test('route nodes stay inside the unobscured map viewport', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
        initialSimulationDayProvider.overrideWithValue(9710),
      ],
    );
    addTearDown(container.dispose);
    final state = container.read(navigatorProvider);
    const size = Size(320, 568);
    const insets = EdgeInsets.fromLTRB(12, 112, 64, 300);

    final nodes = SolarMapPainter.layoutNodes(
      size,
      state,
      viewportInsets: insets,
    );
    final visibleRect = Rect.fromLTRB(
      insets.left,
      insets.top,
      size.width - insets.right,
      size.height - insets.bottom,
    );

    expect(
      nodes[state.originId]!.dx,
      inInclusiveRange(visibleRect.left, visibleRect.right),
    );
    expect(
      nodes[state.originId]!.dy,
      inInclusiveRange(visibleRect.top, visibleRect.bottom),
    );
    expect(
      nodes[state.destinationId]!.dx,
      inInclusiveRange(visibleRect.left, visibleRect.right),
    );
    expect(
      nodes[state.destinationId]!.dy,
      inInclusiveRange(visibleRect.top, visibleRect.bottom),
    );
  });

  test('map semantics use the same inset layout as painted nodes', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
        initialSimulationDayProvider.overrideWithValue(9710),
      ],
    );
    addTearDown(container.dispose);
    final state = container.read(navigatorProvider);
    const size = Size(320, 568);
    const insets = EdgeInsets.fromLTRB(12, 112, 64, 300);
    final nodes = SolarMapPainter.layoutNodes(
      size,
      state,
      viewportInsets: insets,
    );
    final painter = SolarMapPainter(
      state: state,
      routeProgress: const AlwaysStoppedAnimation(0.2),
      ambientAnimation: const AlwaysStoppedAnimation(0.0),
      onSelectObject: (_) {},
      viewportInsets: insets,
    );

    final semantics = painter.semanticsBuilder(size);
    final origin = semantics.singleWhere(
      (node) => (node.properties.label ?? '').startsWith(state.origin.nameZh),
    );

    expect(origin.rect.center, nodes[state.originId]);
  });

  test('hidden body layer does not expose invisible map buttons', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final state = container
        .read(navigatorProvider)
        .copyWith(enabledLayers: const {MapLayer.orbits});
    final painter = SolarMapPainter(
      state: state,
      routeProgress: const AlwaysStoppedAnimation(0.2),
      ambientAnimation: const AlwaysStoppedAnimation(0.0),
      onSelectObject: (_) {},
      viewportInsets: EdgeInsets.zero,
    );

    expect(painter.semanticsBuilder(const Size(390, 844)), isEmpty);
  });

  test('local-orbit objects follow time-dependent relative positions', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final baseState = container
        .read(navigatorProvider)
        .copyWith(mapViewMode: MapViewMode.solar);
    final firstState = baseState.copyWith(
      positions: _replacePositions(baseState.positions, const [
        ObjectPosition(
          id: 'sol/earth',
          xAu: 1,
          yAu: 0,
          zAu: 0,
          distanceToParentAu: 1,
          dayFromJ2000: 0,
          provenance: Provenance(
            nature: DataNature.derived,
            sourceId: 'test',
            noteZh: '测试位置',
          ),
        ),
        ObjectPosition(
          id: 'sol/earth/moon',
          xAu: 1.0025,
          yAu: 0,
          zAu: 0,
          distanceToParentAu: 0.0025,
          dayFromJ2000: 0,
          provenance: Provenance(
            nature: DataNature.derived,
            sourceId: 'test',
            noteZh: '测试位置',
          ),
        ),
      ]),
    );
    final laterState = firstState.copyWith(
      positions: _replacePositions(firstState.positions, const [
        ObjectPosition(
          id: 'sol/earth/moon',
          xAu: 1,
          yAu: 0.0025,
          zAu: 0,
          distanceToParentAu: 0.0025,
          dayFromJ2000: 7,
          provenance: Provenance(
            nature: DataNature.derived,
            sourceId: 'test',
            noteZh: '测试位置',
          ),
        ),
      ]),
    );

    final firstNodes = SolarMapPainter.layoutNodes(
      const Size(800, 600),
      firstState,
    );
    final laterNodes = SolarMapPainter.layoutNodes(
      const Size(800, 600),
      laterState,
    );
    final firstVector =
        firstNodes['sol/earth/moon']! - firstNodes['sol/earth']!;
    final laterVector =
        laterNodes['sol/earth/moon']! - laterNodes['sol/earth']!;
    final firstAngle = math.atan2(firstVector.dy, firstVector.dx);
    final laterAngle = math.atan2(laterVector.dy, laterVector.dx);

    expect((laterAngle - firstAngle).abs(), greaterThan(math.pi / 3));
  });

  test('compact solar labels never overlap after collision filtering', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final state = container
        .read(navigatorProvider)
        .copyWith(mapViewMode: MapViewMode.solar);
    const size = Size(320, 568);
    const insets = EdgeInsets.fromLTRB(12, 112, 64, 228);

    final labelRects = SolarMapPainter.layoutLabelRects(
      size,
      state,
      viewportInsets: insets,
    );
    final labels = labelRects.values.toList();

    expect(labels, isNotEmpty);
    expect(labelRects, contains(state.selectedObjectId));
    for (var first = 0; first < labels.length; first += 1) {
      for (var second = first + 1; second < labels.length; second += 1) {
        expect(
          labels[first].inflate(2).overlaps(labels[second].inflate(2)),
          isFalse,
        );
      }
    }
  });

  test('route anchors include object-backed intermediate waypoints', () {
    final container = ProviderContainer(
      overrides: [
        navigationRepositoryProvider.overrideWithValue(
          FakeNavigationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final baseState = container.read(navigatorProvider);
    final route = fakeRoutePlan(
      strategy: RouteStrategy.safest,
      originId: baseState.originId,
      destinationId: baseState.destinationId,
      departureDayFromJ2000: baseState.simulationDay,
      stops: 1,
      waypoints: const [
        RouteWaypoint(
          labelZh: '离轨机动',
          objectId: 'sol/earth/iss',
          progress: 0,
          actionZh: '离轨',
        ),
        RouteWaypoint(
          labelZh: 'L1 通信确认',
          objectId: 'sol/earth-moon-l1/relay',
          progress: 0.42,
          actionZh: '中继确认',
        ),
        RouteWaypoint(
          labelZh: '抵达制动',
          objectId: 'sol/earth/moon/artemis-base',
          progress: 1,
          actionZh: '抵达',
        ),
      ],
    );
    final state = baseState.copyWith(routes: [route]);
    final nodes = SolarMapPainter.layoutNodes(const Size(800, 600), state);

    expect(SolarMapPainter.routeAnchors(nodes, state), [
      nodes[state.originId],
      nodes['sol/earth-moon-l1/relay'],
      nodes[state.destinationId],
    ]);
  });

  test(
    'solar view keeps active route facilities when their layer is hidden',
    () {
      final container = ProviderContainer(
        overrides: [
          navigationRepositoryProvider.overrideWithValue(
            FakeNavigationRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final baseState = container.read(navigatorProvider);
      final state = baseState.copyWith(
        mapViewMode: MapViewMode.solar,
        enabledLayers: {...baseState.enabledLayers}
          ..remove(MapLayer.facilities),
      );

      final nodes = SolarMapPainter.layoutNodes(const Size(800, 600), state);

      expect(nodes, contains(state.originId));
      expect(nodes, contains(state.destinationId));
      expect(SolarMapPainter.routeAnchors(nodes, state), hasLength(2));
    },
  );
}

List<ObjectPosition> _replacePositions(
  List<ObjectPosition> positions,
  List<ObjectPosition> replacements,
) {
  final byId = {for (final position in positions) position.id: position};
  for (final replacement in replacements) {
    byId[replacement.id] = replacement;
  }
  return byId.values.toList(growable: false);
}

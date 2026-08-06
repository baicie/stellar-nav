import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigation_repository.dart';

class FakeNavigationRepository implements NavigationRepository {
  double? lastPositionDay;
  String? lastDestinationId;

  late final List<CelestialObject> catalog = [
    fakeObject('sol/sun', '太阳', 'Sun', ObjectKind.star, parentId: null),
    fakeObject(
      'sol/earth',
      '地球',
      'Earth',
      ObjectKind.planet,
      parentId: 'sol/sun',
    ),
    fakeObject(
      'sol/earth/moon',
      '月球',
      'Moon',
      ObjectKind.moon,
      parentId: 'sol/earth',
    ),
    fakeObject(
      'sol/earth/iss',
      '国际空间站',
      'ISS',
      ObjectKind.orbitalStation,
      parentId: 'sol/earth',
    ),
    fakeObject(
      'sol/earth/moon/artemis-base',
      '阿尔忒弥斯月面基地',
      'Artemis Base',
      ObjectKind.surfaceBase,
      parentId: 'sol/earth/moon',
    ),
    fakeObject(
      'sol/mars',
      '火星',
      'Mars',
      ObjectKind.planet,
      parentId: 'sol/sun',
    ),
    fakeObject(
      'sol/earth-moon-l1/relay',
      '地月 L1 中继站',
      'L1 Relay',
      ObjectKind.relay,
      parentId: 'sol/earth',
    ),
  ];

  @override
  List<CelestialObject> loadCatalog() => catalog;

  @override
  List<ObjectPosition> positionsAt(double dayFromJ2000) {
    lastPositionDay = dayFromJ2000;
    return catalog
        .map(
          (object) => ObjectPosition(
            id: object.id,
            xAu: switch (object.id) {
              'sol/sun' => 0,
              'sol/mars' => 1.5,
              'sol/earth/moon' || 'sol/earth/moon/artemis-base' => 1.0025,
              _ => 1,
            },
            yAu: object.id == 'sol/mars' ? 0.3 : 0,
            zAu: 0,
            distanceToParentAu: 0.1,
            dayFromJ2000: dayFromJ2000,
            provenance: fakeProvenance(DataNature.derived),
          ),
        )
        .toList();
  }

  @override
  List<RoutePlan> planRoutes({
    required String originId,
    required String destinationId,
    required double departureDayFromJ2000,
    required String vehicleId,
  }) {
    lastDestinationId = destinationId;
    return RouteStrategy.values
        .map(
          (strategy) => fakeRoutePlan(
            strategy: strategy,
            originId: originId,
            destinationId: destinationId,
            departureDayFromJ2000: departureDayFromJ2000,
          ),
        )
        .toList();
  }

  @override
  List<CelestialObject> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return catalog.where((item) => item.reachable).toList();
    }
    return catalog
        .where(
          (object) =>
              object.nameZh.contains(normalized) ||
              object.nameEn.toLowerCase().contains(normalized) ||
              object.aliases.any(
                (alias) => alias.toLowerCase().contains(normalized),
              ),
        )
        .toList();
  }

  @override
  List<SourceRef> loadSources() => const [
    SourceRef(
      id: 'test',
      label: 'NASA 测试数据源',
      url: 'https://science.nasa.gov/solar-system/',
      accessedAtUtc: '2026-08-05T00:00:00Z',
    ),
  ];
}

RoutePlan fakeRoutePlan({
  required RouteStrategy strategy,
  required String originId,
  required String destinationId,
  required double departureDayFromJ2000,
  List<RouteWaypoint> waypoints = const [],
  int stops = 0,
}) => RoutePlan(
  id: '${strategy.name}:$originId:$destinationId',
  strategy: strategy,
  titleZh: strategy.labelZh,
  summaryZh: '测试路线',
  originId: originId,
  destinationId: destinationId,
  departureDayFromJ2000: departureDayFromJ2000,
  durationDays: 3,
  distanceAu: 0.00257,
  deltaVKms: 3.2,
  communicationDelayMinSeconds: 1.2,
  communicationDelayMaxSeconds: 1.4,
  riskScore: 20,
  recommendationScore: 80,
  stops: stops,
  window: WindowAssessment(
    quality: 0.8,
    rating: WindowRating.good,
    ratingZh: '窗口良好',
    cycleDays: 27,
    daysToBestWindow: 2,
    provenance: const Provenance(
      nature: DataNature.simulated,
      sourceId: 'astronav-simulation-v1',
      noteZh: '基于目录演示相位的教学窗口模拟，不是任务级发射窗口',
    ),
  ),
  waypoints: waypoints,
  provenance: fakeProvenance(DataNature.simulated),
  disclaimerZh: '教学模拟',
);

CelestialObject fakeObject(
  String id,
  String nameZh,
  String nameEn,
  ObjectKind kind, {
  required String? parentId,
}) => CelestialObject(
  id: id,
  systemId: 'sol',
  parentId: parentId,
  nameZh: nameZh,
  nameEn: nameEn,
  aliases: [nameEn.toLowerCase()],
  kind: kind,
  descriptionZh: '$nameZh 的科普测试说明，展示来源和数据性质。',
  accentArgb: switch (kind) {
    ObjectKind.star => 0xffffc857,
    ObjectKind.planet => 0xff67a9ff,
    ObjectKind.surfaceBase => 0xffff766d,
    _ => 0xff5eead4,
  },
  mapRadius: 6,
  reachable: kind != ObjectKind.star,
  statusZh: kind.isFacility ? '测试设施' : '自然天体',
  orbit: parentId == null
      ? null
      : OrbitData(
          parentId: parentId,
          semiMajorAxisAu: id == 'sol/mars' ? 1.52 : 1,
          eccentricity: 0.01,
          orbitalPeriodDays: id == 'sol/mars' ? 687 : 365,
          inclinationDeg: 0,
          phaseAtJ2000Rad: 0,
          provenance: fakeProvenance(
            kind == ObjectKind.relay
                ? DataNature.fictional
                : DataNature.derived,
          ),
        ),
  facts: List.generate(
    5,
    (index) => ScienceFact(
      key: 'fact$index',
      labelZh: ['平均半径', '表面重力', '公转周期', '自转周期', '平均温度'][index],
      value: index + 1,
      unit: '测试单位',
      displayZh: '${index + 1} 测试单位',
      provenance: fakeProvenance(DataNature.observed),
    ),
  ),
  provenance: fakeProvenance(
    kind == ObjectKind.surfaceBase || kind == ObjectKind.relay
        ? DataNature.fictional
        : DataNature.observed,
  ),
);

Provenance fakeProvenance(DataNature nature) =>
    Provenance(nature: nature, sourceId: 'test', noteZh: '测试数据');

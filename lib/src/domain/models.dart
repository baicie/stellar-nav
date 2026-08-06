enum DataNature {
  observed,
  derived,
  simulated,
  fictional;

  static DataNature fromJson(String value) => switch (value) {
    'observed' => observed,
    'derived' => derived,
    'simulated' => simulated,
    'fictional' => fictional,
    _ => throw FormatException('Unknown data nature: $value'),
  };

  String get labelZh => switch (this) {
    observed => '观测数据',
    derived => '推导数据',
    simulated => '模拟数据',
    fictional => '虚构设定',
  };

  String get shortLabelZh => switch (this) {
    observed => '观测',
    derived => '推导',
    simulated => '模拟',
    fictional => '虚构',
  };
}

class SourceRef {
  const SourceRef({
    required this.id,
    required this.label,
    required this.url,
    required this.accessedAtUtc,
  });

  factory SourceRef.fromJson(Map<String, dynamic> json) => SourceRef(
    id: json['id'] as String,
    label: json['label'] as String,
    url: json['url'] as String,
    accessedAtUtc: json['accessedAtUtc'] as String,
  );

  final String id;
  final String label;
  final String url;
  final String accessedAtUtc;
}

class Provenance {
  const Provenance({
    required this.nature,
    required this.sourceId,
    required this.noteZh,
  });

  factory Provenance.fromJson(Map<String, dynamic> json) => Provenance(
    nature: DataNature.fromJson(json['nature'] as String),
    sourceId: json['sourceId'] as String,
    noteZh: json['noteZh'] as String,
  );

  final DataNature nature;
  final String sourceId;
  final String noteZh;
}

enum ObjectKind {
  star,
  planet,
  dwarfPlanet,
  moon,
  asteroid,
  orbitalStation,
  surfaceBase,
  relay;

  static ObjectKind fromJson(String value) => ObjectKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => throw FormatException('Unknown object kind: $value'),
  );

  String get labelZh => switch (this) {
    star => '恒星',
    planet => '行星',
    dwarfPlanet => '矮行星',
    moon => '天然卫星',
    asteroid => '小行星',
    orbitalStation => '轨道设施',
    surfaceBase => '表面基地',
    relay => '中继节点',
  };

  bool get isFacility => switch (this) {
    orbitalStation || surfaceBase || relay => true,
    _ => false,
  };
}

class OrbitData {
  const OrbitData({
    required this.parentId,
    required this.semiMajorAxisAu,
    required this.eccentricity,
    required this.orbitalPeriodDays,
    required this.inclinationDeg,
    required this.phaseAtJ2000Rad,
    required this.provenance,
  });

  factory OrbitData.fromJson(Map<String, dynamic> json) => OrbitData(
    parentId: json['parentId'] as String,
    semiMajorAxisAu: (json['semiMajorAxisAu'] as num).toDouble(),
    eccentricity: (json['eccentricity'] as num).toDouble(),
    orbitalPeriodDays: (json['orbitalPeriodDays'] as num).toDouble(),
    inclinationDeg: (json['inclinationDeg'] as num).toDouble(),
    phaseAtJ2000Rad: (json['phaseAtJ2000Rad'] as num).toDouble(),
    provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
  );

  final String parentId;
  final double semiMajorAxisAu;
  final double eccentricity;
  final double orbitalPeriodDays;
  final double inclinationDeg;
  final double phaseAtJ2000Rad;
  final Provenance provenance;
}

class ScienceFact {
  const ScienceFact({
    required this.key,
    required this.labelZh,
    required this.value,
    required this.unit,
    required this.displayZh,
    required this.provenance,
  });

  factory ScienceFact.fromJson(Map<String, dynamic> json) => ScienceFact(
    key: json['key'] as String,
    labelZh: json['labelZh'] as String,
    value: (json['value'] as num).toDouble(),
    unit: json['unit'] as String,
    displayZh: json['displayZh'] as String,
    provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
  );

  final String key;
  final String labelZh;
  final double value;
  final String unit;
  final String displayZh;
  final Provenance provenance;
}

class CelestialObject {
  const CelestialObject({
    required this.id,
    required this.systemId,
    required this.parentId,
    required this.nameZh,
    required this.nameEn,
    required this.aliases,
    required this.kind,
    required this.descriptionZh,
    required this.accentArgb,
    required this.mapRadius,
    required this.reachable,
    required this.statusZh,
    required this.orbit,
    required this.facts,
    required this.provenance,
  });

  factory CelestialObject.fromJson(Map<String, dynamic> json) =>
      CelestialObject(
        id: json['id'] as String,
        systemId: json['systemId'] as String,
        parentId: json['parentId'] as String?,
        nameZh: json['nameZh'] as String,
        nameEn: json['nameEn'] as String,
        aliases: (json['aliases'] as List<dynamic>).cast<String>(),
        kind: ObjectKind.fromJson(json['kind'] as String),
        descriptionZh: json['descriptionZh'] as String,
        accentArgb: (json['accentArgb'] as num).toInt(),
        mapRadius: (json['mapRadius'] as num).toDouble(),
        reachable: json['reachable'] as bool,
        statusZh: json['statusZh'] as String,
        orbit: json['orbit'] == null
            ? null
            : OrbitData.fromJson(json['orbit'] as Map<String, dynamic>),
        facts: (json['facts'] as List<dynamic>)
            .map((item) => ScienceFact.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        provenance: Provenance.fromJson(
          json['provenance'] as Map<String, dynamic>,
        ),
      );

  final String id;
  final String systemId;
  final String? parentId;
  final String nameZh;
  final String nameEn;
  final List<String> aliases;
  final ObjectKind kind;
  final String descriptionZh;
  final int accentArgb;
  final double mapRadius;
  final bool reachable;
  final String statusZh;
  final OrbitData? orbit;
  final List<ScienceFact> facts;
  final Provenance provenance;
}

class ObjectPosition {
  const ObjectPosition({
    required this.id,
    required this.xAu,
    required this.yAu,
    required this.zAu,
    required this.distanceToParentAu,
    required this.dayFromJ2000,
    required this.provenance,
  });

  factory ObjectPosition.fromJson(Map<String, dynamic> json) => ObjectPosition(
    id: json['id'] as String,
    xAu: (json['xAu'] as num).toDouble(),
    yAu: (json['yAu'] as num).toDouble(),
    zAu: (json['zAu'] as num).toDouble(),
    distanceToParentAu: (json['distanceToParentAu'] as num).toDouble(),
    dayFromJ2000: (json['dayFromJ2000'] as num).toDouble(),
    provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
  );

  final String id;
  final double xAu;
  final double yAu;
  final double zAu;
  final double distanceToParentAu;
  final double dayFromJ2000;
  final Provenance provenance;
}

enum WindowRating {
  excellent,
  good,
  limited,
  closed;

  static WindowRating fromJson(String value) => WindowRating.values.firstWhere(
    (rating) => rating.name == value,
    orElse: () => throw FormatException('Unknown window rating: $value'),
  );
}

class WindowAssessment {
  const WindowAssessment({
    required this.quality,
    required this.rating,
    required this.ratingZh,
    required this.cycleDays,
    required this.daysToBestWindow,
    required this.provenance,
  });

  factory WindowAssessment.fromJson(Map<String, dynamic> json) =>
      WindowAssessment(
        quality: (json['quality'] as num).toDouble(),
        rating: WindowRating.fromJson(json['rating'] as String),
        ratingZh: json['ratingZh'] as String,
        cycleDays: (json['cycleDays'] as num).toDouble(),
        daysToBestWindow: (json['daysToBestWindow'] as num).toDouble(),
        provenance: Provenance.fromJson(
          json['provenance'] as Map<String, dynamic>,
        ),
      );

  final double quality;
  final WindowRating rating;
  final String ratingZh;
  final double cycleDays;
  final double daysToBestWindow;
  final Provenance provenance;
}

enum RouteStrategy {
  fastest,
  fuelEfficient,
  safest;

  static RouteStrategy fromJson(String value) =>
      RouteStrategy.values.firstWhere(
        (strategy) => strategy.name == value,
        orElse: () => throw FormatException('Unknown route strategy: $value'),
      );

  String get labelZh => switch (this) {
    fastest => '最快',
    fuelEfficient => '省燃料',
    safest => '低风险',
  };
}

class RouteWaypoint {
  const RouteWaypoint({
    required this.labelZh,
    required this.objectId,
    required this.progress,
    required this.actionZh,
  });

  factory RouteWaypoint.fromJson(Map<String, dynamic> json) => RouteWaypoint(
    labelZh: json['labelZh'] as String,
    objectId: json['objectId'] as String?,
    progress: (json['progress'] as num).toDouble(),
    actionZh: json['actionZh'] as String,
  );

  final String labelZh;
  final String? objectId;
  final double progress;
  final String actionZh;
}

class RoutePlan {
  const RoutePlan({
    required this.id,
    required this.strategy,
    required this.titleZh,
    required this.summaryZh,
    required this.originId,
    required this.destinationId,
    required this.departureDayFromJ2000,
    required this.durationDays,
    required this.distanceAu,
    required this.deltaVKms,
    required this.communicationDelayMinSeconds,
    required this.communicationDelayMaxSeconds,
    required this.riskScore,
    required this.recommendationScore,
    required this.stops,
    required this.window,
    required this.waypoints,
    required this.provenance,
    required this.disclaimerZh,
  });

  factory RoutePlan.fromJson(Map<String, dynamic> json) => RoutePlan(
    id: json['id'] as String,
    strategy: RouteStrategy.fromJson(json['strategy'] as String),
    titleZh: json['titleZh'] as String,
    summaryZh: json['summaryZh'] as String,
    originId: json['originId'] as String,
    destinationId: json['destinationId'] as String,
    departureDayFromJ2000: (json['departureDayFromJ2000'] as num).toDouble(),
    durationDays: (json['durationDays'] as num).toDouble(),
    distanceAu: (json['distanceAu'] as num).toDouble(),
    deltaVKms: (json['deltaVKms'] as num).toDouble(),
    communicationDelayMinSeconds: (json['communicationDelayMinSeconds'] as num)
        .toDouble(),
    communicationDelayMaxSeconds: (json['communicationDelayMaxSeconds'] as num)
        .toDouble(),
    riskScore: (json['riskScore'] as num).toDouble(),
    recommendationScore: (json['recommendationScore'] as num).toDouble(),
    stops: (json['stops'] as num).toInt(),
    window: WindowAssessment.fromJson(json['window'] as Map<String, dynamic>),
    waypoints: (json['waypoints'] as List<dynamic>)
        .map((item) => RouteWaypoint.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    provenance: Provenance.fromJson(json['provenance'] as Map<String, dynamic>),
    disclaimerZh: json['disclaimerZh'] as String,
  );

  final String id;
  final RouteStrategy strategy;
  final String titleZh;
  final String summaryZh;
  final String originId;
  final String destinationId;
  final double departureDayFromJ2000;
  final double durationDays;
  final double distanceAu;
  final double deltaVKms;
  final double communicationDelayMinSeconds;
  final double communicationDelayMaxSeconds;
  final double riskScore;
  final double recommendationScore;
  final int stops;
  final WindowAssessment window;
  final List<RouteWaypoint> waypoints;
  final Provenance provenance;
  final String disclaimerZh;
}

import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationRepositoryProvider = Provider<NavigationRepository>(
  (ref) =>
      throw StateError('NavigationRepository must be overridden at startup'),
);

final initialSimulationDayProvider = Provider<double>((ref) {
  final j2000 = DateTime.utc(2000, 1, 1, 12);
  return DateTime.now().toUtc().difference(j2000).inMinutes / 1440;
});

final navigatorProvider =
    NotifierProvider<NavigatorController, NavigationState>(
      NavigatorController.new,
    );

enum MapViewMode { route, solar }

enum NavigatorPanel { overview, search, details, routes, layers, timeline }

enum MapLayer {
  bodies,
  orbits,
  routes,
  facilities,
  communications,
  spaceWeather,
  risk;

  String get labelZh => switch (this) {
    bodies => '天体',
    orbits => '轨道',
    routes => '航线',
    facilities => '空间设施',
    communications => '通信网络',
    spaceWeather => '空间天气',
    risk => '风险区域',
  };
}

class NavigationState {
  const NavigationState({
    required this.catalog,
    required this.sources,
    required this.positions,
    required this.searchResults,
    required this.routes,
    required this.originId,
    required this.destinationId,
    required this.selectedObjectId,
    required this.selectedStrategy,
    required this.simulationDay,
    required this.query,
    required this.mapViewMode,
    required this.panel,
    required this.enabledLayers,
    required this.isNavigating,
    required this.isRealTime,
  });

  final List<CelestialObject> catalog;
  final Map<String, SourceRef> sources;
  final List<ObjectPosition> positions;
  final List<CelestialObject> searchResults;
  final List<RoutePlan> routes;
  final String originId;
  final String destinationId;
  final String selectedObjectId;
  final RouteStrategy selectedStrategy;
  final double simulationDay;
  final String query;
  final MapViewMode mapViewMode;
  final NavigatorPanel panel;
  final Set<MapLayer> enabledLayers;
  final bool isNavigating;
  final bool isRealTime;

  CelestialObject? objectById(String id) {
    for (final object in catalog) {
      if (object.id == id) return object;
    }
    return null;
  }

  ObjectPosition? positionById(String id) {
    for (final position in positions) {
      if (position.id == id) return position;
    }
    return null;
  }

  CelestialObject get origin => objectById(originId)!;
  CelestialObject get destination => objectById(destinationId)!;
  CelestialObject get selectedObject => objectById(selectedObjectId)!;
  RoutePlan? get selectedRoute {
    for (final route in routes) {
      if (route.strategy == selectedStrategy) return route;
    }
    return routes.isEmpty ? null : routes.first;
  }

  NavigationState copyWith({
    List<CelestialObject>? catalog,
    Map<String, SourceRef>? sources,
    List<ObjectPosition>? positions,
    List<CelestialObject>? searchResults,
    List<RoutePlan>? routes,
    String? originId,
    String? destinationId,
    String? selectedObjectId,
    RouteStrategy? selectedStrategy,
    double? simulationDay,
    String? query,
    MapViewMode? mapViewMode,
    NavigatorPanel? panel,
    Set<MapLayer>? enabledLayers,
    bool? isNavigating,
    bool? isRealTime,
  }) => NavigationState(
    catalog: catalog ?? this.catalog,
    sources: sources ?? this.sources,
    positions: positions ?? this.positions,
    searchResults: searchResults ?? this.searchResults,
    routes: routes ?? this.routes,
    originId: originId ?? this.originId,
    destinationId: destinationId ?? this.destinationId,
    selectedObjectId: selectedObjectId ?? this.selectedObjectId,
    selectedStrategy: selectedStrategy ?? this.selectedStrategy,
    simulationDay: simulationDay ?? this.simulationDay,
    query: query ?? this.query,
    mapViewMode: mapViewMode ?? this.mapViewMode,
    panel: panel ?? this.panel,
    enabledLayers: enabledLayers ?? this.enabledLayers,
    isNavigating: isNavigating ?? this.isNavigating,
    isRealTime: isRealTime ?? this.isRealTime,
  );
}

class NavigatorController extends Notifier<NavigationState> {
  late NavigationRepository _repository;

  @override
  NavigationState build() {
    _repository = ref.read(navigationRepositoryProvider);
    final catalog = _repository.loadCatalog();
    final day = ref.read(initialSimulationDayProvider);
    const originId = 'sol/earth/iss';
    const destinationId = 'sol/earth/moon/artemis-base';
    final routes = _repository.planRoutes(
      originId: originId,
      destinationId: destinationId,
      departureDayFromJ2000: day,
      vehicleId: 'aurora-demo',
    );
    return NavigationState(
      catalog: catalog,
      sources: {
        for (final source in _repository.loadSources()) source.id: source,
      },
      positions: _repository.positionsAt(day),
      searchResults: catalog
          .where((object) => object.reachable)
          .take(8)
          .toList(),
      routes: routes,
      originId: originId,
      destinationId: destinationId,
      selectedObjectId: destinationId,
      selectedStrategy: RouteStrategy.safest,
      simulationDay: day,
      query: '',
      mapViewMode: MapViewMode.route,
      panel: NavigatorPanel.overview,
      enabledLayers: const {
        MapLayer.bodies,
        MapLayer.orbits,
        MapLayer.routes,
        MapLayer.facilities,
        MapLayer.communications,
      },
      isNavigating: false,
      isRealTime: true,
    );
  }

  void search(String query) {
    state = state.copyWith(
      query: query,
      searchResults: _repository.search(query),
      panel: NavigatorPanel.search,
    );
  }

  void selectObject(String id) {
    if (state.objectById(id) == null) return;
    state = state.copyWith(selectedObjectId: id, panel: NavigatorPanel.details);
  }

  void setOrigin(String id) {
    final object = state.objectById(id);
    if (object == null || !object.reachable || id == state.destinationId) {
      return;
    }
    _replan(originId: id, destinationId: state.destinationId);
  }

  void setDestination(String id) {
    final object = state.objectById(id);
    if (object == null || !object.reachable || id == state.originId) return;
    _replan(originId: state.originId, destinationId: id);
  }

  void swapEndpoints() {
    _replan(originId: state.destinationId, destinationId: state.originId);
  }

  void chooseStrategy(RouteStrategy strategy) {
    state = state.copyWith(
      selectedStrategy: strategy,
      panel: NavigatorPanel.routes,
      isNavigating: false,
    );
  }

  void setSimulationDay(double day) {
    final positions = _repository.positionsAt(day);
    final routes = _repository.planRoutes(
      originId: state.originId,
      destinationId: state.destinationId,
      departureDayFromJ2000: day,
      vehicleId: 'aurora-demo',
    );
    state = state.copyWith(
      simulationDay: day,
      positions: positions,
      routes: routes,
      isRealTime: false,
      panel: NavigatorPanel.timeline,
      isNavigating: false,
    );
  }

  void shiftSimulationDay(double delta) =>
      setSimulationDay(state.simulationDay + delta);

  void returnToRealTime() {
    final j2000 = DateTime.utc(2000, 1, 1, 12);
    final day = DateTime.now().toUtc().difference(j2000).inMinutes / 1440;
    setSimulationDay(day);
    state = state.copyWith(isRealTime: true);
  }

  void setMapViewMode(MapViewMode mode) {
    state = state.copyWith(mapViewMode: mode);
  }

  void openPanel(NavigatorPanel panel) {
    state = state.copyWith(panel: panel);
  }

  void toggleLayer(MapLayer layer) {
    final layers = {...state.enabledLayers};
    layers.contains(layer) ? layers.remove(layer) : layers.add(layer);
    state = state.copyWith(enabledLayers: layers);
  }

  void startNavigation() {
    if (state.selectedRoute == null) return;
    state = state.copyWith(isNavigating: true, panel: NavigatorPanel.routes);
  }

  void stopNavigation() {
    state = state.copyWith(isNavigating: false);
  }

  void _replan({required String originId, required String destinationId}) {
    final routes = _repository.planRoutes(
      originId: originId,
      destinationId: destinationId,
      departureDayFromJ2000: state.simulationDay,
      vehicleId: 'aurora-demo',
    );
    state = state.copyWith(
      originId: originId,
      destinationId: destinationId,
      selectedObjectId: destinationId,
      routes: routes,
      selectedStrategy: RouteStrategy.safest,
      panel: NavigatorPanel.routes,
      isNavigating: false,
    );
  }
}

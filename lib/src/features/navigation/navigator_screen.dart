import 'dart:math' as math;

import 'package:astro_nav/src/design/tokens.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:astro_nav/src/features/navigation/widgets/map_controls.dart';
import 'package:astro_nav/src/features/navigation/widgets/mission_hud.dart';
import 'package:astro_nav/src/features/navigation/widgets/navigation_header.dart';
import 'package:astro_nav/src/features/navigation/widgets/navigation_panel.dart';
import 'package:astro_nav/src/features/navigation/widgets/solar_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavigatorScreen extends ConsumerStatefulWidget {
  const NavigatorScreen({super.key});

  @override
  ConsumerState<NavigatorScreen> createState() => _NavigatorScreenState();
}

class _NavigatorScreenState extends ConsumerState<NavigatorScreen>
    with TickerProviderStateMixin {
  final _mapKey = GlobalKey<SolarMapState>();
  late final AnimationController _ambientController;
  late final AnimationController _routeController;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _routeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    if (animationsDisabled == _animationsDisabled) return;
    _animationsDisabled = animationsDisabled;
    if (animationsDisabled) {
      _ambientController
        ..stop()
        ..value = 0;
      _routeController
        ..stop()
        ..value = 0;
    } else {
      _ambientController.repeat();
      if (ref.read(navigatorProvider).isNavigating) {
        _routeController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _routeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(navigatorProvider);
    ref.listen<bool>(navigatorProvider.select((value) => value.isNavigating), (
      previous,
      next,
    ) {
      if (next) {
        _routeController.value = 0;
        if (!_animationsDisabled) {
          _routeController.forward();
        }
      } else {
        _routeController
          ..stop()
          ..value = 0;
      }
    });
    final controller = ref.read(navigatorProvider.notifier);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 980;
          if (desktop) {
            return Row(
              children: [
                SizedBox(
                  width: AppSizes.desktopDock,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.space,
                      border: Border(right: BorderSide(color: AppColors.line)),
                    ),
                    child: SafeArea(
                      right: false,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.lg,
                              AppSpacing.md,
                            ),
                            child: Column(
                              children: [
                                const DesktopBrand(),
                                const SizedBox(height: AppSpacing.lg),
                                NavigationHeader(
                                  state: state,
                                  showBrand: false,
                                  onSearch: controller.search,
                                  onOpenSearch: () => controller.openPanel(
                                    NavigatorPanel.search,
                                  ),
                                  onReturnToRealTime:
                                      controller.returnToRealTime,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: NavigationPanel(state: state, desktop: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _MapStage(
                    state: state,
                    mapKey: _mapKey,
                    ambientAnimation: _ambientController,
                    routeProgress: _routeController,
                    desktop: true,
                    panelInset: 0,
                  ),
                ),
              ],
            );
          }

          final compactMobile =
              constraints.maxWidth < 360 || constraints.maxHeight < 700;
          final panelHeight = _mobilePanelHeight(
            state.panel,
            constraints.maxHeight,
            mapViewMode: state.mapViewMode,
            compact: compactMobile,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: _MapStage(
                  state: state,
                  mapKey: _mapKey,
                  ambientAnimation: _ambientController,
                  routeProgress: _routeController,
                  desktop: false,
                  panelInset: panelHeight,
                  compactControls: compactMobile,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.maxBottomPanel,
                  ),
                  child: SizedBox(
                    key: const Key('mobile-navigation-panel'),
                    height: panelHeight,
                    width: double.infinity,
                    child: NavigationPanel(state: state, desktop: false),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

double _mobilePanelHeight(
  NavigatorPanel panel,
  double availableHeight, {
  required MapViewMode mapViewMode,
  required bool compact,
}) {
  if (compact) {
    final desired = switch (panel) {
      NavigatorPanel.overview => 248.0,
      NavigatorPanel.routes => 304.0,
      NavigatorPanel.timeline => 284.0,
      NavigatorPanel.search ||
      NavigatorPanel.details ||
      NavigatorPanel.layers => 352.0,
    };
    final fraction = switch (panel) {
      NavigatorPanel.overview => 0.44,
      NavigatorPanel.routes => 0.54,
      NavigatorPanel.timeline => 0.5,
      _ => 0.62,
    };
    final height = math.min(desired, availableHeight * fraction);
    return mapViewMode == MapViewMode.solar ? math.min(height, 228) : height;
  }

  final desired = switch (panel) {
    NavigatorPanel.overview => 336.0,
    NavigatorPanel.routes => 390.0,
    NavigatorPanel.timeline => 330.0,
    NavigatorPanel.search ||
    NavigatorPanel.details ||
    NavigatorPanel.layers => 408.0,
  };
  final fraction = switch (panel) {
    NavigatorPanel.overview => 0.56,
    NavigatorPanel.routes => 0.62,
    NavigatorPanel.timeline => 0.56,
    _ => 0.62,
  };
  return math.min(desired, availableHeight * fraction);
}

class _MapStage extends ConsumerWidget {
  const _MapStage({
    required this.state,
    required this.mapKey,
    required this.ambientAnimation,
    required this.routeProgress,
    required this.desktop,
    required this.panelInset,
    this.compactControls = false,
  });

  final NavigationState state;
  final GlobalKey<SolarMapState> mapKey;
  final Animation<double> ambientAnimation;
  final Animation<double> routeProgress;
  final bool desktop;
  final double panelInset;
  final bool compactControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(navigatorProvider.notifier);
    final topOffset = desktop ? 16.0 : MediaQuery.paddingOf(context).top + 72;
    final viewportInsets = EdgeInsets.fromLTRB(
      AppSpacing.sm,
      desktop ? 72 : topOffset + 52,
      AppSizes.iconButton + AppSpacing.md,
      panelInset + 52,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: SolarMap(
            key: mapKey,
            state: state,
            routeProgress: routeProgress,
            ambientAnimation: ambientAnimation,
            onSelectObject: controller.selectObject,
            viewportInsets: viewportInsets,
          ),
        ),
        if (!desktop)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: NavigationHeader(
                state: state,
                onSearch: controller.search,
                onOpenSearch: () => controller.openPanel(NavigatorPanel.search),
                onReturnToRealTime: controller.returnToRealTime,
              ),
            ),
          ),
        Positioned(
          left: desktop ? AppSpacing.md : AppSpacing.sm,
          top: topOffset,
          child: MapModeSwitch(
            value: state.mapViewMode,
            onChanged: controller.setMapViewMode,
          ),
        ),
        Positioned(
          right: desktop ? AppSpacing.md : AppSpacing.sm,
          top: desktop ? 16 : topOffset + 48,
          child: MapToolbar(
            compact: compactControls,
            onFocus: () => mapKey.currentState?.resetView(),
            onLayers: () => controller.openPanel(NavigatorPanel.layers),
            onTimeline: () => controller.openPanel(NavigatorPanel.timeline),
            onZoomIn: () => mapKey.currentState?.zoomIn(),
            onZoomOut: () => mapKey.currentState?.zoomOut(),
            onReset: () => mapKey.currentState?.resetView(),
          ),
        ),
        Positioned(
          left: desktop ? AppSpacing.md : AppSpacing.sm,
          bottom: panelInset + AppSpacing.sm,
          child: MapStatusStrip(state: state),
        ),
        if (state.isNavigating && state.selectedRoute != null)
          Positioned(
            left: desktop ? AppSpacing.md : AppSpacing.sm,
            right: !desktop && compactControls
                ? AppSizes.iconButton + AppSpacing.lg
                : null,
            top: desktop ? 72 : topOffset + 48,
            child: MissionHud(
              route: state.selectedRoute!,
              progress: routeProgress,
              onStop: controller.stopNavigation,
              compact: !desktop && compactControls,
            ),
          ),
      ],
    );
  }
}

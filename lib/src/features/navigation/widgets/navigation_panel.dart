import 'package:astro_nav/src/design/tokens.dart';
import 'package:astro_nav/src/domain/formatters.dart';
import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:astro_nav/src/widgets/provenance_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class NavigationPanel extends ConsumerWidget {
  const NavigationPanel({
    required this.state,
    required this.desktop,
    super.key,
  });

  final NavigationState state;
  final bool desktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(navigatorProvider.notifier);
    final panelProvenance = switch (state.panel) {
      NavigatorPanel.routes => state.selectedRoute?.provenance,
      NavigatorPanel.details => state.selectedObject.provenance,
      _ => null,
    };
    final content = switch (state.panel) {
      NavigatorPanel.overview => _OverviewPanel(state: state),
      NavigatorPanel.search => _SearchPanel(state: state),
      NavigatorPanel.details => _DetailsPanel(state: state),
      NavigatorPanel.routes => _RoutesPanel(state: state),
      NavigatorPanel.layers => _LayersPanel(state: state),
      NavigatorPanel.timeline => _TimelinePanel(state: state),
    };

    return Material(
      color: desktop ? AppColors.space : AppColors.panel,
      shape: desktop
          ? null
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadii.medium),
              ),
              side: BorderSide(color: AppColors.line),
            ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!desktop)
              Center(
                child: Container(
                  width: 38,
                  height: 3,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lineBright,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (state.panel != NavigatorPanel.overview)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? AppSpacing.lg : AppSpacing.md,
                  desktop ? AppSpacing.md : AppSpacing.xs,
                  desktop ? AppSpacing.lg : AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回任务概览',
                      onPressed: () =>
                          controller.openPanel(NavigatorPanel.overview),
                      icon: const Icon(LucideIcons.arrowLeft, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _panelTitle(state.panel),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (panelProvenance != null)
                      ProvenanceBadge(
                        provenance: panelProvenance,
                        compact: true,
                      ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? AppSpacing.lg : AppSpacing.md,
                  state.panel == NavigatorPanel.overview
                      ? AppSpacing.md
                      : AppSpacing.sm,
                  desktop ? AppSpacing.lg : AppSpacing.md,
                  AppSpacing.md,
                ),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _panelTitle(NavigatorPanel panel) => switch (panel) {
  NavigatorPanel.overview => '任务规划',
  NavigatorPanel.search => '搜索目的地',
  NavigatorPanel.details => '对象详情',
  NavigatorPanel.routes => '候选航线',
  NavigatorPanel.layers => '地图图层',
  NavigatorPanel.timeline => '模拟时间轴',
};

const _unavailableRouteMessage = '当前教学模型尚未生成可用航线';

class _OverviewPanel extends ConsumerWidget {
  const _OverviewPanel({required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(navigatorProvider.notifier);
    final route = state.selectedRoute;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前任务',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${state.origin.nameZh} → ${state.destination.nameZh}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '交换起点和终点',
                onPressed: controller.swapEndpoints,
                icon: const Icon(LucideIcons.arrowRightLeft, size: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (route == null) ...[
            const _UnavailableRouteNotice(),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton.icon(
            key: const Key('open-routes-button'),
            onPressed: route == null
                ? null
                : () => controller.openPanel(NavigatorPanel.routes),
            icon: const Icon(LucideIcons.route, size: 18),
            label: Text(
              route == null ? '暂无可比较航线' : '比较 ${state.routes.length} 条航线',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _EndpointRow(
            label: '起点',
            object: state.origin,
            icon: LucideIcons.navigation,
            onTap: () => controller.selectObject(state.originId),
          ),
          const SizedBox(height: AppSpacing.xs),
          _EndpointRow(
            label: '终点',
            object: state.destination,
            icon: LucideIcons.mapPin,
            onTap: () => controller.selectObject(state.destinationId),
          ),
          const SizedBox(height: AppSpacing.md),
          if (route != null) ...[
            Row(
              children: [
                Expanded(
                  child: _InlineMetric(
                    label: route.window.ratingZh,
                    value: '质量 ${(route.window.quality * 100).round()}%',
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _InlineMetric(
                    label: route.titleZh,
                    value: formatDuration(route.durationDays),
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => controller.openPanel(NavigatorPanel.search),
                  icon: const Icon(LucideIcons.search, size: 17),
                  label: const Text('换目的地'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      controller.openPanel(NavigatorPanel.timeline),
                  icon: const Icon(LucideIcons.history, size: 17),
                  label: const Text('调整时间'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnavailableRouteNotice extends StatelessWidget {
  const _UnavailableRouteNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: _unavailableRouteMessage,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.06),
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 17, color: AppColors.amber),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(_unavailableRouteMessage)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.label,
    required this.object,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final CelestialObject object;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label，${object.nameZh}，查看详情',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: AppColors.cyan),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 34,
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
              Expanded(
                child: Text(
                  object.nameZh,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color, fontSize: 10),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends ConsumerWidget {
  const _SearchPanel({required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(navigatorProvider.notifier);
    if (state.searchResults.isEmpty) {
      return const Center(child: Text('没有找到匹配的太阳系对象'));
    }
    return ListView.separated(
      itemCount: state.searchResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final object = state.searchResults[index];
        return ListTile(
          key: Key('search-result-${object.id}'),
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Color(object.accentArgb),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.text.withValues(alpha: 0.25)),
            ),
          ),
          title: Text(object.nameZh),
          subtitle: Text(
            '${object.kind.labelZh} · ${object.nameEn}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: ProvenanceBadge(
            provenance: object.provenance,
            compact: true,
          ),
          onTap: () => controller.selectObject(object.id),
        );
      },
    );
  }
}

class _DetailsPanel extends ConsumerWidget {
  const _DetailsPanel({required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(navigatorProvider.notifier);
    final object = state.selectedObject;
    final source = state.sources[object.provenance.sourceId];
    return ListView(
      key: const Key('object-details-scroll-view'),
      padding: EdgeInsets.zero,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Color(object.accentArgb),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(object.accentArgb).withValues(alpha: 0.24),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    object.nameZh,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${object.kind.labelZh} · ${object.nameEn}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    object.statusZh,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppColors.cyan),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          object.descriptionZh,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (source != null)
          Text(
            '来源：${source.label} · 快照 ${source.accessedAtUtc.substring(0, 10)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < object.facts.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          Builder(
            builder: (context) {
              final fact = object.facts[index];
              final factSource = state.sources[fact.provenance.sourceId];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fact.labelZh,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            fact.displayZh,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        ProvenanceBadge(
                          provenance: fact.provenance,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '来源：${factSource?.label ?? fact.provenance.sourceId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textDim,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        if (object.reachable &&
            object.id != state.originId &&
            object.id != state.destinationId) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('set-origin-button'),
            onPressed: () => controller.setOrigin(object.id),
            icon: const Icon(LucideIcons.locateFixed, size: 18),
            label: Text('设${object.nameZh}为起点'),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton.icon(
            key: const Key('set-destination-button'),
            onPressed: () => controller.setDestination(object.id),
            icon: const Icon(LucideIcons.navigation, size: 18),
            label: Text('导航到${object.nameZh}'),
          ),
        ],
      ],
    );
  }
}

class _RoutesPanel extends ConsumerWidget {
  const _RoutesPanel({required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(navigatorProvider.notifier);
    final route = state.selectedRoute;
    if (route == null) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _UnavailableRouteNotice(),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('navigation-toggle-button'),
              onPressed: null,
              icon: const Icon(LucideIcons.navigation, size: 18),
              label: const Text('暂无可开始航线'),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: state.routes.map((candidate) {
              final selected = candidate.strategy == state.selectedStrategy;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    key: Key('strategy-${candidate.strategy.name}'),
                    selected: selected,
                    showCheckmark: false,
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        candidate.strategy.labelZh,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    onSelected: (_) =>
                        controller.chooseStrategy(candidate.strategy),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _RouteMetric(
                  icon: LucideIcons.clock3,
                  label: '预计耗时',
                  value: formatDuration(route.durationDays),
                ),
              ),
              Expanded(
                child: _RouteMetric(
                  icon: LucideIcons.gauge,
                  label: 'Δv',
                  value: formatDeltaV(route.deltaVKms),
                ),
              ),
              Expanded(
                child: _RouteMetric(
                  icon: LucideIcons.radio,
                  label: '通信时延',
                  value: formatCommunicationDelay(
                    route.communicationDelayMinSeconds,
                    route.communicationDelayMaxSeconds,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _RouteStopsSummary(state: state, route: route),
          const Divider(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  route.summaryZh,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '风险 ${formatRisk(route.riskScore)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: route.riskScore < 40
                          ? AppColors.green
                          : AppColors.amber,
                    ),
                  ),
                  Text(
                    '推荐 ${route.recommendationScore.round()}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: AppColors.cyan),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: route.window.quality,
            minHeight: 4,
            color: AppColors.amber,
            backgroundColor: AppColors.line,
            borderRadius: BorderRadius.circular(2),
            semanticsLabel: '教学窗口质量',
            semanticsValue: '${(route.window.quality * 100).round()}%',
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${route.window.ratingZh} · 距下一个模型最优时机 ${formatDuration(route.window.daysToBestWindow)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ProvenanceBadge(
                provenance: route.window.provenance,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('navigation-toggle-button'),
            onPressed: state.isNavigating
                ? controller.stopNavigation
                : controller.startNavigation,
            style: state.isNavigating
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: AppColors.voidBlack,
                  )
                : null,
            icon: Icon(
              state.isNavigating ? LucideIcons.square : LucideIcons.navigation,
              size: 18,
            ),
            label: Text(state.isNavigating ? '结束模拟导航' : '开始模拟导航'),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            route.disclaimerZh,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textDim,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStopsSummary extends StatelessWidget {
  const _RouteStopsSummary({required this.state, required this.route});

  final NavigationState state;
  final RoutePlan route;

  @override
  Widget build(BuildContext context) {
    final intermediateStops = route.waypoints
        .where(
          (waypoint) =>
              waypoint.objectId != null &&
              waypoint.objectId != route.originId &&
              waypoint.objectId != route.destinationId,
        )
        .map(
          (waypoint) =>
              state.objectById(waypoint.objectId!)?.nameZh ?? waypoint.labelZh,
        )
        .toList(growable: false);
    final label = intermediateStops.isEmpty
        ? '直达 · 无中继停靠'
        : '经停 ${route.stops} 站 · ${intermediateStops.join('、')}';

    return Semantics(
      label: '航线停靠，$label',
      excludeSemantics: true,
      child: Row(
        children: [
          const Icon(
            LucideIcons.waypoints,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LayersPanel extends ConsumerWidget {
  const _LayersPanel({required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(navigatorProvider.notifier);
    return ListView.separated(
      itemCount: MapLayer.values.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final layer = MapLayer.values[index];
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(layer.labelZh),
          subtitle: Text(_layerDescription(layer)),
          value: state.enabledLayers.contains(layer),
          onChanged: (_) => controller.toggleLayer(layer),
        );
      },
    );
  }
}

String _layerDescription(MapLayer layer) => switch (layer) {
  MapLayer.bodies => '主要天体、卫星与对象标签',
  MapLayer.orbits => '简化轨道与轨道层级',
  MapLayer.routes => '当前候选航线与航行器',
  MapLayer.facilities => '空间站、基地与中继节点',
  MapLayer.communications => '模拟通信链路与光行时',
  MapLayer.spaceWeather => '示意太阳活动传播，不是实时预报',
  MapLayer.risk => '教学风险区域，不可用于任务决策',
};

class _TimelinePanel extends ConsumerStatefulWidget {
  const _TimelinePanel({required this.state});

  final NavigationState state;

  @override
  ConsumerState<_TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends ConsumerState<_TimelinePanel> {
  late double _previewDay;

  @override
  void initState() {
    super.initState();
    _previewDay = widget.state.simulationDay;
  }

  @override
  void didUpdateWidget(covariant _TimelinePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.simulationDay != widget.state.simulationDay) {
      _previewDay = widget.state.simulationDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(navigatorProvider.notifier);
    final route = widget.state.selectedRoute;
    final selectedPosition = widget.state.positionById(
      widget.state.selectedObjectId,
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatSimulationDate(_previewDay),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    if (route == null)
                      Text(
                        _unavailableRouteMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${route.window.ratingZh} · 质量 ${(route.window.quality * 100).round()}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.amber),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ProvenanceBadge(
                            provenance: route.window.provenance,
                            compact: true,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: controller.returnToRealTime,
                child: const Text('现在'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Slider(
            key: const Key('simulation-time-slider'),
            value: _previewDay,
            min: widget.state.simulationDay - 390,
            max: widget.state.simulationDay + 390,
            divisions: 780,
            label: formatSimulationDate(_previewDay),
            semanticFormatterCallback: (value) =>
                '模拟日期 ${formatSimulationDate(value)}',
            onChanged: (value) => setState(() => _previewDay = value),
            onChangeEnd: controller.setSimulationDay,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (selectedPosition != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.state.selectedObject.nameZh}位置模型',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ProvenanceBadge(
                  provenance: selectedPosition.provenance,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              _TimeStepButton(
                label: '后退 30 天',
                text: '−30 天',
                onPressed: () => controller.shiftSimulationDay(-30),
              ),
              _TimeStepButton(
                label: '后退 1 天',
                text: '−1 天',
                onPressed: () => controller.shiftSimulationDay(-1),
              ),
              _TimeStepButton(
                label: '前进 1 天',
                text: '+1 天',
                onPressed: () => controller.shiftSimulationDay(1),
              ),
              _TimeStepButton(
                label: '前进 30 天',
                text: '+30 天',
                onPressed: () => controller.shiftSimulationDay(30),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '天体位置为 J2000 教学轨道推导；拖动结束后才重新计算航线。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TimeStepButton extends StatelessWidget {
  const _TimeStepButton({
    required this.label,
    required this.text,
    required this.onPressed,
  });

  final String label;
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Semantics(
          label: label,
          button: true,
          excludeSemantics: true,
          onTap: onPressed,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(text, maxLines: 1),
          ),
        ),
      ),
    );
  }
}

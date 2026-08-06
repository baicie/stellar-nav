import 'package:astro_nav/src/design/tokens.dart';
import 'package:astro_nav/src/domain/formatters.dart';
import 'package:astro_nav/src/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MissionHud extends StatelessWidget {
  const MissionHud({
    required this.route,
    required this.progress,
    required this.onStop,
    this.compact = false,
    super.key,
  });

  final RoutePlan route;
  final Animation<double> progress;
  final VoidCallback onStop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '模拟导航状态',
      child: Container(
        width: compact ? null : 278,
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.panel,
          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) {
            final value = progress.value.clamp(0.0, 1.0);
            final stage = _currentStage(route, value);
            final remaining = route.durationDays * (1 - value);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.navigation,
                      color: AppColors.cyan,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '模拟导航 · ${route.titleZh}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '结束模拟导航',
                      onPressed: onStop,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.square, size: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  stage.labelZh,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.amber),
                ),
                const SizedBox(height: 2),
                Text(
                  stage.actionZh,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 9),
                LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  color: AppColors.cyan,
                  backgroundColor: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '剩余 ${formatDuration(remaining)}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    Text(
                      '链路 ${formatCommunicationDelay(route.communicationDelayMinSeconds, route.communicationDelayMaxSeconds)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.green,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

RouteWaypoint _currentStage(RoutePlan route, double progress) {
  if (route.waypoints.isEmpty) {
    return const RouteWaypoint(
      labelZh: '转移巡航',
      objectId: null,
      progress: 0.5,
      actionZh: '保持航向并监控通信链路',
    );
  }
  var stage = route.waypoints.first;
  for (final waypoint in route.waypoints) {
    if (waypoint.progress <= progress) stage = waypoint;
  }
  return stage;
}

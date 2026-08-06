import 'package:astro_nav/src/design/tokens.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class MapModeSwitch extends StatelessWidget {
  const MapModeSwitch({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final MapViewMode value;
  final ValueChanged<MapViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      child: SegmentedButton<MapViewMode>(
        segments: const [
          ButtonSegment(
            value: MapViewMode.route,
            icon: Icon(LucideIcons.route, size: 16),
            label: Text('航线', maxLines: 1),
          ),
          ButtonSegment(
            value: MapViewMode.solar,
            icon: Icon(LucideIcons.orbit, size: 16),
            label: Text('太阳系', maxLines: 1),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 6),
          ),
          visualDensity: VisualDensity.compact,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.cyan.withValues(alpha: 0.16)
                : AppColors.panel,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.cyan
                : AppColors.textMuted,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadii.medium)),
            ),
          ),
        ),
      ),
    );
  }
}

class MapToolbar extends StatelessWidget {
  const MapToolbar({
    required this.onFocus,
    required this.onLayers,
    required this.onTimeline,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    this.compact = false,
    super.key,
  });

  final VoidCallback onFocus;
  final VoidCallback onLayers;
  final VoidCallback onTimeline;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolButton(
          label: '聚焦当前航线',
          icon: LucideIcons.locateFixed,
          onPressed: onFocus,
          emphasized: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ToolButton(
          label: '图层',
          icon: LucideIcons.layers3,
          onPressed: onLayers,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ToolButton(
          label: '时间轴',
          icon: LucideIcons.history,
          onPressed: onTimeline,
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xs),
          _ToolButton(
            label: '放大地图',
            icon: LucideIcons.plus,
            onPressed: onZoomIn,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ToolButton(
            label: '缩小地图',
            icon: LucideIcons.minus,
            onPressed: onZoomOut,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ToolButton(
            label: '重置视角',
            icon: LucideIcons.rotateCcw,
            onPressed: onReset,
          ),
        ],
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: emphasized
            ? IconButton.styleFrom(
                backgroundColor: AppColors.cyan,
                foregroundColor: AppColors.voidBlack,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(AppRadii.medium),
                  ),
                ),
              )
            : null,
        icon: Icon(icon, size: 19),
      ),
    );
  }
}

class MapStatusStrip extends StatelessWidget {
  const MapStatusStrip({required this.state, super.key});

  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    final route = state.selectedRoute;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: state.isRealTime ? AppColors.green : AppColors.amber,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              state.isRealTime ? '现实时间输入' : '模拟时间',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
            if (route != null) ...[
              const SizedBox(width: 9),
              Container(width: 1, height: 12, color: AppColors.line),
              const SizedBox(width: 9),
              Text(
                route.window.ratingZh,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.amber,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

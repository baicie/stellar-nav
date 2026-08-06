import 'dart:math' as math;

import 'package:astro_nav/src/design/tokens.dart';
import 'package:astro_nav/src/domain/models.dart';
import 'package:astro_nav/src/features/navigation/navigator_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class SolarMap extends StatefulWidget {
  const SolarMap({
    required this.state,
    required this.routeProgress,
    required this.ambientAnimation,
    required this.onSelectObject,
    this.viewportInsets = EdgeInsets.zero,
    super.key,
  });

  final NavigationState state;
  final Animation<double> routeProgress;
  final Animation<double> ambientAnimation;
  final ValueChanged<String> onSelectObject;
  final EdgeInsets viewportInsets;

  @override
  State<SolarMap> createState() => SolarMapState();
}

class SolarMapState extends State<SolarMap> {
  final TransformationController _transformationController =
      TransformationController();

  void resetView() {
    _transformationController.value = Matrix4.identity();
  }

  void zoomIn() => _scaleBy(1.28);
  void zoomOut() => _scaleBy(0.78);

  void _scaleBy(double factor) {
    final current = _transformationController.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.72, 4.5);
    _transformationController.value = Matrix4.diagonal3Values(next, next, 1);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.state.mapViewMode == MapViewMode.route
          ? '航线交互地图，可双指缩放和平移'
          : '太阳系轨道交互地图，可双指缩放和平移',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return InteractiveViewer(
            transformationController: _transformationController,
            minScale: 0.72,
            maxScale: 4.5,
            boundaryMargin: const EdgeInsets.all(180),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: zoomIn,
              onTapUp: (details) {
                final nodes = SolarMapPainter.layoutNodes(
                  size,
                  widget.state,
                  viewportInsets: widget.viewportInsets,
                );
                String? nearestId;
                var nearestDistance = 28.0;
                for (final entry in nodes.entries) {
                  final distance =
                      (entry.value - details.localPosition).distance;
                  if (distance < nearestDistance) {
                    nearestId = entry.key;
                    nearestDistance = distance;
                  }
                }
                if (nearestId != null) widget.onSelectObject(nearestId);
              },
              child: CustomPaint(
                size: size,
                painter: SolarMapPainter(
                  state: widget.state,
                  routeProgress: widget.routeProgress,
                  ambientAnimation: widget.ambientAnimation,
                  onSelectObject: widget.onSelectObject,
                  viewportInsets: widget.viewportInsets,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SolarMapPainter extends CustomPainter {
  SolarMapPainter({
    required this.state,
    required this.routeProgress,
    required this.ambientAnimation,
    required this.onSelectObject,
    required this.viewportInsets,
  }) : super(repaint: Listenable.merge([routeProgress, ambientAnimation]));

  final NavigationState state;
  final Animation<double> routeProgress;
  final Animation<double> ambientAnimation;
  final ValueChanged<String> onSelectObject;
  final EdgeInsets viewportInsets;

  static Map<String, Offset> layoutNodes(
    Size size,
    NavigationState state, {
    EdgeInsets viewportInsets = EdgeInsets.zero,
  }) {
    final viewport = _visibleRect(size, viewportInsets);
    if (state.mapViewMode == MapViewMode.route) {
      return _routeNodes(viewport, state);
    }
    return _solarNodes(viewport, state);
  }

  static Map<String, Rect> layoutLabelRects(
    Size size,
    NavigationState state, {
    EdgeInsets viewportInsets = EdgeInsets.zero,
  }) {
    final viewport = _visibleRect(size, viewportInsets);
    final nodes = layoutNodes(size, state, viewportInsets: viewportInsets);
    return {
      for (final label in _layoutLabels(viewport, state, nodes))
        label.objectId: label.bounds,
    };
  }

  static List<_MapLabelPlacement> _layoutLabels(
    Rect viewport,
    NavigationState state,
    Map<String, Offset> nodes,
  ) {
    final candidates =
        nodes.entries.where((entry) {
          final object = state.objectById(entry.key);
          return object != null && _shouldShowLabel(state, object);
        }).toList()..sort((left, right) {
          final priority = _labelPriority(
            state,
            left.key,
          ).compareTo(_labelPriority(state, right.key));
          return priority == 0 ? left.key.compareTo(right.key) : priority;
        });

    final occupiedRects = <Rect>[];
    final placements = <_MapLabelPlacement>[];
    for (final entry in candidates) {
      final object = state.objectById(entry.key)!;
      final label = _labelPainter(state, object);
      final desiredOffsets = [
        entry.value + const Offset(12, -16),
        entry.value + const Offset(12, 7),
        entry.value + Offset(-label.width - 12, -16),
        entry.value + Offset(-label.width - 12, 7),
      ];
      Rect? fallback;
      Rect? placement;
      for (final desired in desiredOffsets) {
        final offset = Offset(
          desired.dx.clamp(
            viewport.left + 4,
            math.max(viewport.left + 4, viewport.right - label.width - 4),
          ),
          desired.dy.clamp(
            viewport.top + 4,
            math.max(viewport.top + 4, viewport.bottom - label.height - 4),
          ),
        );
        final candidate = offset & label.size;
        fallback ??= candidate;
        final collisionBounds = candidate.inflate(3);
        if (occupiedRects.every((rect) => !rect.overlaps(collisionBounds))) {
          placement = candidate;
          break;
        }
      }

      placement ??= object.id == state.selectedObjectId ? fallback : null;
      if (placement == null) continue;
      placements.add(
        _MapLabelPlacement(
          objectId: object.id,
          bounds: placement,
          painter: label,
        ),
      );
      occupiedRects.add(placement.inflate(3));
    }
    return placements;
  }

  static Rect _visibleRect(Size size, EdgeInsets insets) {
    final left = insets.left
        .clamp(0.0, math.max(0.0, size.width - 1))
        .toDouble();
    final top = insets.top
        .clamp(0.0, math.max(0.0, size.height - 1))
        .toDouble();
    final right = (size.width - insets.right)
        .clamp(left + 1, size.width)
        .toDouble();
    final bottom = (size.height - insets.bottom)
        .clamp(top + 1, size.height)
        .toDouble();
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Map<String, Offset> _routeNodes(Rect viewport, NavigationState state) {
    final nodes = <String, Offset>{};
    final start = Offset(
      viewport.left + viewport.width * 0.22,
      viewport.top + viewport.height * 0.68,
    );
    final end = Offset(
      viewport.left + viewport.width * 0.7,
      viewport.top + viewport.height * 0.32,
    );
    nodes[state.originId] = start;
    nodes[state.destinationId] = end;
    final nodeBounds = viewport.deflate(
      math.min(18.0, viewport.shortestSide * 0.12),
    );

    void addAncestors(String id, Offset anchor, bool startSide) {
      var current = state.objectById(id);
      var depth = 0;
      while (current?.parentId != null && depth < 3) {
        final parent = state.objectById(current!.parentId!);
        if (parent == null || nodes.containsKey(parent.id)) break;
        final direction = startSide ? -1.0 : 1.0;
        nodes[parent.id] = _clampPoint(
          anchor + Offset(direction * (24 + depth * 18), 26 + depth * 18),
          nodeBounds,
        );
        current = parent;
        depth += 1;
      }
    }

    addAncestors(state.originId, start, true);
    addAncestors(state.destinationId, end, false);

    final route = state.selectedRoute;
    if (route != null) {
      final delta = end - start;
      final normal = Offset(-delta.dy, delta.dx);
      final unitNormal = normal / math.max(1.0, normal.distance);
      var intermediateIndex = 0;
      for (final waypoint in route.waypoints) {
        final objectId = waypoint.objectId;
        if (objectId == null ||
            objectId == state.originId ||
            objectId == state.destinationId ||
            state.objectById(objectId) == null) {
          continue;
        }
        final side = intermediateIndex.isEven ? -1.0 : 1.0;
        final progress = waypoint.progress.clamp(0.08, 0.92);
        nodes[objectId] = _clampPoint(
          Offset.lerp(start, end, progress)! + unitNormal * (34 * side),
          nodeBounds,
        );
        intermediateIndex += 1;
      }
    }
    return nodes;
  }

  static Map<String, Offset> _solarNodes(Rect viewport, NavigationState state) {
    final center = viewport.center;
    final maxRadius = math.max(48.0, viewport.shortestSide * 0.4);
    final nodes = <String, Offset>{'sol/sun': center};
    final positions = {for (final item in state.positions) item.id: item};

    for (final object in state.catalog.where(
      (item) => item.orbit?.parentId == 'sol/sun',
    )) {
      final position = positions[object.id];
      if (position == null || object.orbit == null) continue;
      final angle = math.atan2(position.yAu, position.xAu);
      final radius = _logRadius(object.orbit!.semiMajorAxisAu, maxRadius);
      nodes[object.id] =
          center + Offset(math.cos(angle), math.sin(angle)) * radius;
    }

    final activeRouteObjectIds = <String>{
      state.originId,
      state.destinationId,
      ...?state.selectedRoute?.waypoints
          .map((waypoint) => waypoint.objectId)
          .whereType<String>(),
    };
    final pending = state.catalog
        .where(
          (item) => item.parentId != null && item.orbit?.parentId != 'sol/sun',
        )
        .where(
          (item) =>
              !item.kind.isFacility ||
              state.enabledLayers.contains(MapLayer.facilities) ||
              activeRouteObjectIds.contains(item.id),
        )
        .toList();
    while (pending.isNotEmpty) {
      var progressed = false;
      for (final object in List<CelestialObject>.of(pending)) {
        final referenceId = object.orbit?.parentId ?? object.parentId!;
        final parent = nodes[referenceId] ?? nodes[object.parentId];
        if (parent == null) continue;
        final position = positions[object.id];
        final referencePosition = positions[referenceId];
        final relativeX = position == null || referencePosition == null
            ? 0.0
            : position.xAu - referencePosition.xAu;
        final relativeY = position == null || referencePosition == null
            ? 0.0
            : position.yAu - referencePosition.yAu;
        final angle = relativeX.abs() + relativeY.abs() > 1.0e-14
            ? math.atan2(relativeY, relativeX)
            : _fallbackAngle(object.id);
        final distance = object.kind == ObjectKind.moon ? 20.0 : 14.0;
        nodes[object.id] =
            parent + Offset(math.cos(angle), math.sin(angle)) * distance;
        pending.remove(object);
        progressed = true;
      }
      if (!progressed) break;
    }
    return nodes;
  }

  static double _fallbackAngle(String objectId) {
    final hash = objectId.codeUnits.fold<int>(0, (value, unit) => value + unit);
    return hash % 360 * math.pi / 180;
  }

  static List<Offset> routeAnchors(
    Map<String, Offset> nodes,
    NavigationState state,
  ) {
    final route = state.selectedRoute;
    final origin = nodes[state.originId];
    final destination = nodes[state.destinationId];
    if (route == null || origin == null || destination == null) {
      return const [];
    }
    final anchors = <({double progress, String id})>[
      (progress: 0, id: state.originId),
      for (final waypoint in route.waypoints)
        if (waypoint.objectId != null &&
            waypoint.objectId != state.originId &&
            waypoint.objectId != state.destinationId &&
            nodes.containsKey(waypoint.objectId))
          (progress: waypoint.progress, id: waypoint.objectId!),
      (progress: 1, id: state.destinationId),
    ]..sort((left, right) => left.progress.compareTo(right.progress));
    return anchors.map((anchor) => nodes[anchor.id]!).toList(growable: false);
  }

  static Offset _clampPoint(Offset point, Rect bounds) => Offset(
    point.dx.clamp(bounds.left, bounds.right).toDouble(),
    point.dy.clamp(bounds.top, bounds.bottom).toDouble(),
  );

  static double _logRadius(double au, double maxRadius) {
    final normalized = math.log(1 + au * 1.55) / math.log(1 + 40 * 1.55);
    return 24 + normalized * (maxRadius - 24);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackground(canvas, size);
    final nodes = layoutNodes(size, state, viewportInsets: viewportInsets);
    if (state.enabledLayers.contains(MapLayer.orbits)) {
      _paintOrbits(canvas, size, nodes);
    }
    if (state.enabledLayers.contains(MapLayer.spaceWeather)) {
      _paintSpaceWeather(canvas, size, nodes);
    }
    if (state.enabledLayers.contains(MapLayer.risk)) {
      _paintRiskZones(canvas, size, nodes);
    }
    if (state.enabledLayers.contains(MapLayer.communications)) {
      _paintCommunications(canvas, nodes);
    }
    if (state.enabledLayers.contains(MapLayer.routes)) {
      _paintRoute(canvas, nodes);
    }
    if (state.enabledLayers.contains(MapLayer.bodies)) {
      _paintObjects(canvas, size, nodes);
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.voidBlack);
    final gridPaint = Paint()
      ..color = AppColors.line.withValues(alpha: 0.15)
      ..strokeWidth = 0.7;
    const step = 72.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final starPaint = Paint();
    for (var index = 0; index < 110; index += 1) {
      final x = ((math.sin(index * 91.73) + 1) * 0.5) * size.width;
      final y = ((math.sin(index * 47.21 + 0.8) + 1) * 0.5) * size.height;
      final pulse =
          0.36 + 0.22 * math.sin(ambientAnimation.value * math.pi * 2 + index);
      starPaint.color = AppColors.text.withValues(
        alpha: pulse.clamp(0.12, 0.58),
      );
      canvas.drawCircle(Offset(x, y), index % 9 == 0 ? 1.2 : 0.65, starPaint);
    }
  }

  void _paintOrbits(Canvas canvas, Size size, Map<String, Offset> nodes) {
    final paint = Paint()
      ..color = AppColors.lineBright.withValues(alpha: 0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    if (state.mapViewMode == MapViewMode.solar) {
      final center = nodes['sol/sun'];
      if (center == null) return;
      final maxRadius = math.max(
        48.0,
        _visibleRect(size, viewportInsets).shortestSide * 0.4,
      );
      for (final object in state.catalog.where(
        (item) => item.orbit?.parentId == 'sol/sun',
      )) {
        final radius = _logRadius(object.orbit!.semiMajorAxisAu, maxRadius);
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * 1.88,
          ),
          paint,
        );
      }
      return;
    }

    final start = nodes[state.originId];
    final end = nodes[state.destinationId];
    if (start == null || end == null) return;
    canvas.drawOval(
      Rect.fromCenter(center: start, width: 126, height: 58),
      paint,
    );
    canvas.drawOval(Rect.fromCenter(center: end, width: 94, height: 44), paint);
  }

  void _paintRoute(Canvas canvas, Map<String, Offset> nodes) {
    if (state.selectedRoute == null) return;
    final anchors = routeAnchors(nodes, state);
    if (anchors.length < 2) return;
    final path = _routePath(anchors);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final distance = metric.length * routeProgress.value.clamp(0.0, 1.0);
    final tangent = metric.getTangentForOffset(distance);
    if (tangent == null) return;
    final angle = tangent.angle;
    canvas.save();
    canvas.translate(tangent.position.dx, tangent.position.dy);
    canvas.rotate(angle);
    final craft = Path()
      ..moveTo(11, 0)
      ..lineTo(-7, -5)
      ..lineTo(-3, 0)
      ..lineTo(-7, 5)
      ..close();
    canvas.drawPath(
      craft,
      Paint()..color = state.isNavigating ? AppColors.amber : AppColors.cyan,
    );
    canvas.restore();
  }

  Path _routePath(List<Offset> anchors) {
    final path = Path()..moveTo(anchors.first.dx, anchors.first.dy);
    for (var index = 0; index < anchors.length - 1; index += 1) {
      final start = anchors[index];
      final end = anchors[index + 1];
      final delta = end - start;
      final normal = Offset(-delta.dy, delta.dx);
      final unitNormal = normal / math.max(1.0, normal.distance);
      final side = index.isEven ? 1.0 : -1.0;
      final bend = unitNormal * math.min(72.0, delta.distance * 0.2) * side;
      path.cubicTo(
        start.dx + delta.dx * 0.33 + bend.dx,
        start.dy + delta.dy * 0.33 + bend.dy,
        start.dx + delta.dx * 0.68 + bend.dx,
        start.dy + delta.dy * 0.68 + bend.dy,
        end.dx,
        end.dy,
      );
    }
    return path;
  }

  void _paintObjects(Canvas canvas, Size size, Map<String, Offset> nodes) {
    for (final entry in nodes.entries) {
      final object = state.objectById(entry.key);
      if (object == null) continue;
      final point = entry.value;
      final color = Color(object.accentArgb);
      final selected = object.id == state.selectedObjectId;
      final radius = object.id == 'sol/sun'
          ? 13.0
          : (object.mapRadius * (selected ? 1.12 : 0.88)).clamp(4.0, 10.0);

      if (selected) {
        canvas.drawCircle(
          point,
          radius + 7 + ambientAnimation.value * 2,
          Paint()
            ..color = AppColors.cyan.withValues(alpha: 0.68)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
      }
      if (object.id == 'sol/sun') {
        canvas.drawCircle(
          point,
          radius + 8,
          Paint()
            ..color = color.withValues(alpha: 0.26)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
      canvas.drawCircle(point, radius, Paint()..color = color);
      canvas.drawCircle(
        point - Offset(radius * 0.25, radius * 0.25),
        radius * 0.32,
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }

    final viewport = _visibleRect(size, viewportInsets);
    for (final label in _layoutLabels(viewport, state, nodes)) {
      label.painter.paint(canvas, label.bounds.topLeft);
    }
  }

  static bool _shouldShowLabel(NavigationState state, CelestialObject object) {
    final isEndpoint =
        object.id == state.originId || object.id == state.destinationId;
    final isWaypoint =
        state.selectedRoute?.waypoints.any(
          (waypoint) => waypoint.objectId == object.id,
        ) ??
        false;
    return isEndpoint ||
        isWaypoint ||
        object.id == state.selectedObjectId ||
        (state.mapViewMode == MapViewMode.solar && !object.kind.isFacility);
  }

  static int _labelPriority(NavigationState state, String objectId) {
    if (objectId == state.selectedObjectId) return 0;
    if (objectId == state.originId || objectId == state.destinationId) return 1;
    final object = state.objectById(objectId);
    if (object?.kind == ObjectKind.star || object?.kind == ObjectKind.planet) {
      return 2;
    }
    return 3;
  }

  static TextPainter _labelPainter(
    NavigationState state,
    CelestialObject object,
  ) {
    final endpoint =
        object.id == state.originId || object.id == state.destinationId;
    return TextPainter(
      text: TextSpan(
        text: object.nameZh,
        style: TextStyle(
          color: endpoint ? AppColors.text : AppColors.textMuted,
          fontSize: endpoint ? 12.5 : 10.5,
          fontWeight: endpoint ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 116);
  }

  void _paintCommunications(Canvas canvas, Map<String, Offset> nodes) {
    final relay = nodes['sol/earth-moon-l1/relay'];
    final origin = nodes[state.originId];
    final destination = nodes[state.destinationId];
    if (origin == null || destination == null) return;
    final paint = Paint()
      ..color = AppColors.green.withValues(alpha: 0.38)
      ..strokeWidth = 1;
    if (relay != null) {
      _drawDashedLine(canvas, origin, relay, paint);
      _drawDashedLine(canvas, relay, destination, paint);
    } else {
      _drawDashedLine(canvas, origin, destination, paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final distance = delta.distance;
    if (distance == 0) return;
    final direction = delta / distance;
    for (var cursor = 0.0; cursor < distance; cursor += 11) {
      canvas.drawLine(
        start + direction * cursor,
        start + direction * math.min(cursor + 5, distance),
        paint,
      );
    }
  }

  void _paintSpaceWeather(Canvas canvas, Size size, Map<String, Offset> nodes) {
    final sun =
        nodes['sol/sun'] ?? Offset(size.width * 0.08, size.height * 0.22);
    final paint = Paint()
      ..color = AppColors.amber.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var index = 0; index < 3; index += 1) {
      final radius = 34.0 + index * 19 + ambientAnimation.value * 5;
      canvas.drawArc(
        Rect.fromCircle(center: sun, radius: radius),
        -0.55,
        1.1,
        false,
        paint,
      );
    }
  }

  void _paintRiskZones(Canvas canvas, Size size, Map<String, Offset> nodes) {
    final earth = nodes['sol/earth'];
    if (earth == null) return;
    canvas.drawArc(
      Rect.fromCircle(
        center: earth,
        radius: math.min(size.shortestSide * 0.12, 54),
      ),
      0.2,
      1.3,
      false,
      Paint()
        ..color = AppColors.coral.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3,
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    if (!state.enabledLayers.contains(MapLayer.bodies)) return const [];
    final nodes = layoutNodes(size, state, viewportInsets: viewportInsets);
    return nodes.entries.map((entry) {
      final object = state.objectById(entry.key)!;
      return CustomPainterSemantics(
        rect: Rect.fromCircle(center: entry.value, radius: 24),
        properties: SemanticsProperties(
          label: '${object.nameZh}，${object.kind.labelZh}，打开详情',
          textDirection: TextDirection.ltr,
          button: true,
          onTap: () => onSelectObject(object.id),
        ),
      );
    }).toList();
  };

  @override
  bool shouldRepaint(covariant SolarMapPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.viewportInsets != viewportInsets;

  @override
  bool shouldRebuildSemantics(covariant SolarMapPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.viewportInsets != viewportInsets;
}

class _MapLabelPlacement {
  const _MapLabelPlacement({
    required this.objectId,
    required this.bounds,
    required this.painter,
  });

  final String objectId;
  final Rect bounds;
  final TextPainter painter;
}

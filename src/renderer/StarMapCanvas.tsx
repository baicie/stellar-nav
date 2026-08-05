import { Canvas, Circle, Path, Skia } from '@shopify/react-native-skia';
import { useEffect, useMemo } from 'react';
import { StyleSheet, useWindowDimensions } from 'react-native';
import {
  Easing,
  cancelAnimation,
  useDerivedValue,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';

import type { MapLayerVisibility } from './layers';

interface NormalizedPoint {
  x: number;
  y: number;
}

interface RouteVisual {
  start: NormalizedPoint;
  control1: NormalizedPoint;
  control2: NormalizedPoint;
  end: NormalizedPoint;
}

interface StarMapCanvasProps {
  destinationAnchor: NormalizedPoint;
  routeId: string;
  routeVisual: RouteVisual;
  isNavigating: boolean;
  reducedMotion: boolean;
  visibleLayers: MapLayerVisibility;
}

function createStarPaths(width: number, height: number) {
  const dim = Skia.PathBuilder.Make();
  const cool = Skia.PathBuilder.Make();
  const warm = Skia.PathBuilder.Make();
  let seed = 9229;
  const next = () => {
    seed = (seed * 16807) % 2147483647;
    return (seed - 1) / 2147483646;
  };

  for (let index = 0; index < 148; index += 1) {
    const x = next() * width;
    const y = next() * height;
    const radius = index % 19 === 0 ? 1.7 : index % 5 === 0 ? 1.15 : 0.62;
    const target = index % 11 === 0 ? warm : index % 3 === 0 ? cool : dim;
    target.addCircle(x, y, radius);
  }

  return { dim: dim.detach(), cool: cool.detach(), warm: warm.detach() };
}

export function StarMapCanvas({
  destinationAnchor,
  routeId,
  routeVisual,
  isNavigating,
  reducedMotion,
  visibleLayers,
}: StarMapCanvasProps) {
  const { width, height } = useWindowDimensions();
  const shipProgress = useSharedValue(0.04);

  useEffect(() => {
    cancelAnimation(shipProgress);

    if (isNavigating && !reducedMotion) {
      shipProgress.value = withRepeat(
        withTiming(1, { duration: 12_000, easing: Easing.inOut(Easing.cubic) }),
        -1,
        false,
      );
    } else {
      shipProgress.value = withTiming(isNavigating ? 0.42 : 0.04, { duration: 520 });
    }

    return () => cancelAnimation(shipProgress);
  }, [isNavigating, reducedMotion, routeId, shipProgress]);

  const starPaths = useMemo(() => createStarPaths(width, height), [width, height]);

  const galaxyPath = useMemo(() => {
    const path = Skia.PathBuilder.Make();
    path.moveTo(-width * 0.2, height * 0.69);
    path.cubicTo(
      width * 0.2,
      height * 0.42,
      width * 0.62,
      height * 0.63,
      width * 1.2,
      height * 0.22,
    );
    return path.detach();
  }, [height, width]);

  const routePath = useMemo(() => {
    const { start, control1, control2, end } = routeVisual;
    return `M ${start.x * width} ${start.y * height} C ${control1.x * width} ${control1.y * height}, ${control2.x * width} ${control2.y * height}, ${end.x * width} ${end.y * height}`;
  }, [height, routeVisual, width]);

  const shipX = useDerivedValue(() => {
    const { start, control1, control2, end } = routeVisual;
    const t = shipProgress.value;
    const inverse = 1 - t;
    const x =
      inverse ** 3 * start.x +
      3 * inverse ** 2 * t * control1.x +
      3 * inverse * t ** 2 * control2.x +
      t ** 3 * end.x;
    return x * width;
  }, [routeVisual, shipProgress, width]);
  const shipY = useDerivedValue(() => {
    const { start, control1, control2, end } = routeVisual;
    const t = shipProgress.value;
    const inverse = 1 - t;
    const y =
      inverse ** 3 * start.y +
      3 * inverse ** 2 * t * control1.y +
      3 * inverse * t ** 2 * control2.y +
      t ** 3 * end.y;
    return y * height;
  }, [height, routeVisual, shipProgress]);

  const destinationX = destinationAnchor.x * width;
  const destinationY = destinationAnchor.y * height;

  return (
    <Canvas style={styles.canvas} accessibilityLabel="动态星图">
      {visibleLayers.stars && (
        <>
          <Path
            path={galaxyPath}
            color="rgba(38, 91, 112, 0.16)"
            style="stroke"
            strokeWidth={116}
          />
          <Path path={galaxyPath} color="rgba(80, 160, 168, 0.1)" style="stroke" strokeWidth={46} />
          <Path
            path={galaxyPath}
            color="rgba(200, 235, 221, 0.08)"
            style="stroke"
            strokeWidth={2}
          />
          <Path path={starPaths.dim} color="rgba(188, 210, 216, 0.58)" />
          <Path path={starPaths.cool} color="rgba(135, 212, 239, 0.82)" />
          <Path path={starPaths.warm} color="rgba(247, 201, 137, 0.9)" />
          <Circle cx={destinationX} cy={destinationY} r={13} color="rgba(86, 226, 236, 0.12)" />
          <Circle cx={destinationX} cy={destinationY} r={5.5} color="#D9FFF2" />
          <Circle cx={destinationX} cy={destinationY} r={2.7} color="#53DDEA" />
        </>
      )}

      {visibleLayers.hazards && (
        <>
          <Circle
            cx={width * 0.53}
            cy={height * 0.26}
            r={width * 0.09}
            color="rgba(6, 10, 14, 0.88)"
          />
          <Circle
            cx={width * 0.53}
            cy={height * 0.26}
            r={width * 0.105}
            color="rgba(245, 105, 108, 0.58)"
            style="stroke"
            strokeWidth={1}
          />
        </>
      )}

      {visibleLayers.routes && (
        <>
          <Path path={routePath} color="rgba(83, 221, 235, 0.22)" style="stroke" strokeWidth={18} />
          <Path
            path={routePath}
            color="rgba(89, 236, 232, 0.92)"
            style="stroke"
            strokeWidth={4.5}
          />
          <Path
            path={routePath}
            color="rgba(224, 255, 246, 0.92)"
            style="stroke"
            strokeWidth={1.2}
          />
          <Circle cx={shipX} cy={shipY} r={16} color="rgba(111, 246, 239, 0.12)" />
          <Circle cx={shipX} cy={shipY} r={7} color="#F3FFF7" />
          <Circle cx={shipX} cy={shipY} r={3.5} color="#53DDEA" />
        </>
      )}
    </Canvas>
  );
}

const styles = StyleSheet.create({
  canvas: {
    ...StyleSheet.absoluteFill,
    pointerEvents: 'none',
  },
});

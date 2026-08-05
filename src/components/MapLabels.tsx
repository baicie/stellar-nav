import { StyleSheet, Text, useWindowDimensions, View } from 'react-native';

import type { Destination } from '../data/catalog';
import { colors, fontFamilies, radii, spacing } from '../design/tokens';
import type { MapLayerVisibility } from '../renderer/layers';

interface MapLabelsProps {
  bottomOcclusion: number;
  destination: Destination;
  visibleLayers: MapLayerVisibility;
}

interface MapLabelLayoutInput {
  bottomOcclusion: number;
  destinationAnchor: Destination['mapAnchor'];
  height: number;
  width: number;
}

const mapLabelHeight = 28;
const minimumLabelTop = 132;

export function getMapLabelLayout({
  bottomOcclusion,
  destinationAnchor,
  height,
  width,
}: MapLabelLayoutInput) {
  const maximumLabelTop = Math.max(
    minimumLabelTop,
    height - Math.max(0, bottomOcclusion) - spacing.sm - mapLabelHeight,
  );

  return {
    destinationLeft: Math.min(width - 120, Math.max(92, destinationAnchor.x * width - 20)),
    destinationTop: Math.min(
      maximumLabelTop,
      Math.max(minimumLabelTop, destinationAnchor.y * height - 32),
    ),
    originTop: Math.min(maximumLabelTop, height * 0.68),
  };
}

export function MapLabels({ bottomOcclusion, destination, visibleLayers }: MapLabelsProps) {
  const { width, height } = useWindowDimensions();
  const { destinationLeft, destinationTop, originTop } = getMapLabelLayout({
    bottomOcclusion,
    destinationAnchor: destination.mapAnchor,
    height,
    width,
  });

  return (
    <View style={[StyleSheet.absoluteFill, styles.overlay]}>
      {visibleLayers.stars && (
        <>
          <View style={[styles.label, styles.origin, { left: width * 0.11, top: originTop }]}>
            <View style={[styles.dot, styles.originDot]} />
            <Text style={styles.labelText}>地球</Text>
          </View>
          <View style={[styles.label, { left: destinationLeft, top: destinationTop }]}>
            <View style={[styles.dot, styles.destinationDot]} />
            <Text style={styles.labelText}>{destination.name}</Text>
          </View>
          <Text style={[styles.regionLabel, { left: width * 0.18, top: height * 0.35 }]}>
            银河系外旋臂
          </Text>
        </>
      )}
      {visibleLayers.hazards && (
        <View style={[styles.hazardLabel, { left: width * 0.48, top: height * 0.17 }]}>
          <Text style={styles.hazardText}>引力异常区</Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  overlay: {
    pointerEvents: 'none',
  },
  label: {
    alignItems: 'center',
    backgroundColor: 'rgba(3, 7, 12, 0.68)',
    borderColor: 'rgba(190, 225, 228, 0.22)',
    borderRadius: radii.pill,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 5,
    paddingHorizontal: 8,
    paddingVertical: 4,
    position: 'absolute',
  },
  origin: {
    borderColor: 'rgba(143, 226, 181, 0.4)',
  },
  dot: {
    borderRadius: radii.pill,
    height: 6,
    width: 6,
  },
  originDot: {
    backgroundColor: colors.green,
  },
  destinationDot: {
    backgroundColor: colors.cyan,
  },
  labelText: {
    color: colors.text,
    fontSize: 11,
    fontWeight: '600',
  },
  hazardLabel: {
    borderLeftColor: 'rgba(245, 105, 108, 0.6)',
    borderLeftWidth: 2,
    paddingLeft: 6,
    position: 'absolute',
  },
  hazardText: {
    color: colors.coral,
    fontFamily: fontFamilies.display,
    fontSize: 9,
    letterSpacing: 0.5,
  },
  regionLabel: {
    color: 'rgba(211, 244, 238, 0.54)',
    fontFamily: fontFamilies.display,
    fontSize: 10,
    letterSpacing: 0.8,
    position: 'absolute',
    transform: [{ rotate: '-12deg' }],
  },
});

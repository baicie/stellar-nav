import { ChevronDown, Layers3, Search } from 'lucide-react-native';
import { BlurView } from 'expo-blur';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import type { Destination } from '../data/catalog';
import { colors, fontFamilies, radii, spacing } from '../design/tokens';
import { IconButton } from './IconButton';

interface TopNavProps {
  destination: Destination;
  onDestinationPress: () => void;
  onLayersPress: () => void;
}

export function TopNav({ destination, onDestinationPress, onLayersPress }: TopNavProps) {
  return (
    <BlurView intensity={32} tint="dark" style={styles.panel}>
      <View style={styles.brandRow}>
        <View style={styles.brandMark}>
          <View style={styles.brandCore} />
        </View>
        <Text style={styles.brand}>缺德导航</Text>
        <Text style={styles.mode}>任务演示 · 0.1</Text>
        <View style={styles.spacer} />
        <IconButton icon={Search} label="搜索目的地" onPress={onDestinationPress} tone="cyan" />
        <IconButton icon={Layers3} label="打开星图图层" onPress={onLayersPress} />
      </View>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`选择目的地，当前为 ${destination.name}`}
        onPress={onDestinationPress}
        style={({ pressed }) => [styles.destinationButton, pressed && styles.pressed]}
      >
        <View style={styles.locationColumn}>
          <View style={styles.locationRow}>
            <View style={[styles.locationDot, styles.originDot]} />
            <Text style={styles.locationLabel}>当前位置</Text>
            <Text style={styles.locationValue}>地球 · 太阳系</Text>
          </View>
          <View style={styles.connector} />
          <View style={styles.locationRow}>
            <View style={[styles.locationDot, styles.destinationDot]} />
            <Text style={styles.locationLabel}>目的地</Text>
            <Text style={styles.locationValue} numberOfLines={1}>
              {destination.name}
            </Text>
            <ChevronDown color={colors.textMuted} size={16} strokeWidth={1.8} />
          </View>
        </View>
        <View style={styles.destinationMeta}>
          <Text style={styles.destinationCategory}>{destination.category}</Text>
          <Text style={styles.destinationSubtitle} numberOfLines={1}>
            {destination.subtitle}
          </Text>
        </View>
      </Pressable>
    </BlurView>
  );
}

const styles = StyleSheet.create({
  panel: {
    borderBottomColor: colors.line,
    borderBottomWidth: 1,
    paddingBottom: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
  },
  brandRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.sm,
    height: 34,
  },
  brandMark: {
    alignItems: 'center',
    backgroundColor: 'rgba(83, 221, 234, 0.16)',
    borderColor: 'rgba(83, 221, 234, 0.54)',
    borderRadius: radii.sm,
    borderWidth: 1,
    height: 22,
    justifyContent: 'center',
    width: 22,
  },
  brandCore: {
    backgroundColor: colors.cyan,
    borderRadius: radii.pill,
    height: 7,
    width: 7,
  },
  brand: {
    color: colors.text,
    fontFamily: fontFamilies.displayStrong,
    fontSize: 13,
    letterSpacing: 0.6,
  },
  mode: {
    color: colors.textQuiet,
    fontSize: 10,
  },
  spacer: {
    flex: 1,
  },
  destinationButton: {
    backgroundColor: 'rgba(7, 17, 24, 0.64)',
    borderColor: 'rgba(190, 225, 228, 0.12)',
    borderRadius: radii.md,
    borderWidth: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: spacing.sm,
    minHeight: 56,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
  },
  pressed: {
    opacity: 0.76,
  },
  locationColumn: {
    justifyContent: 'center',
  },
  locationRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
  },
  locationDot: {
    borderRadius: radii.pill,
    height: 7,
    width: 7,
  },
  originDot: {
    backgroundColor: colors.green,
  },
  destinationDot: {
    backgroundColor: colors.coral,
  },
  locationLabel: {
    color: colors.textQuiet,
    fontSize: 10,
    width: 48,
  },
  locationValue: {
    color: colors.text,
    flexShrink: 1,
    fontSize: 12,
    fontWeight: '600',
  },
  connector: {
    borderLeftColor: 'rgba(190, 225, 228, 0.35)',
    borderLeftWidth: 1,
    height: 7,
    marginLeft: 3,
  },
  destinationMeta: {
    alignItems: 'flex-end',
    justifyContent: 'center',
    maxWidth: 112,
  },
  destinationCategory: {
    color: colors.cyan,
    fontFamily: fontFamilies.display,
    fontSize: 10,
    letterSpacing: 0.4,
    textTransform: 'uppercase',
  },
  destinationSubtitle: {
    color: colors.textMuted,
    fontSize: 10,
    marginTop: 3,
    textAlign: 'right',
  },
});

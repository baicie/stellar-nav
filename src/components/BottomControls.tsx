import { Map, Navigation2, Share2, Square } from 'lucide-react-native';
import { BlurView } from 'expo-blur';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { colors, fontFamilies, radii, spacing } from '../design/tokens';

interface BottomControlsProps {
  isNavigating: boolean;
  onShare: () => void;
  onMapPress: () => void;
  onStartPress: () => void;
  compact: boolean;
}

export function BottomControls({
  isNavigating,
  onShare,
  onMapPress,
  onStartPress,
  compact,
}: BottomControlsProps) {
  return (
    <BlurView intensity={34} tint="dark" style={[styles.panel, compact && styles.panelCompact]}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="打开地图视图"
        onPress={onMapPress}
        style={({ pressed }) => [styles.tab, pressed && styles.pressed]}
      >
        <Map color={colors.textMuted} size={18} strokeWidth={1.8} />
        <Text style={styles.tabLabel}>星图</Text>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="分享当前航线"
        onPress={onShare}
        style={({ pressed }) => [styles.tab, pressed && styles.pressed]}
      >
        <Share2 color={colors.textMuted} size={18} strokeWidth={1.8} />
        <Text style={styles.tabLabel}>分享</Text>
      </Pressable>
      <View style={styles.tabSpacer} />
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={isNavigating ? '结束航行' : '开始导航'}
        onPress={onStartPress}
        style={({ pressed }) => [
          styles.startButton,
          isNavigating && styles.stopButton,
          pressed && styles.pressed,
        ]}
      >
        {isNavigating ? (
          <Square color={colors.canvas} fill={colors.canvas} size={15} strokeWidth={2} />
        ) : (
          <Navigation2 color={colors.canvas} size={17} strokeWidth={2.2} />
        )}
        <Text style={styles.startLabel}>{isNavigating ? '结束航行' : '开始导航'}</Text>
      </Pressable>
    </BlurView>
  );
}

const styles = StyleSheet.create({
  panel: {
    alignItems: 'center',
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    marginHorizontal: spacing.lg,
    marginTop: spacing.sm,
    minHeight: 64,
    padding: spacing.sm,
  },
  panelCompact: {
    minHeight: 58,
  },
  tab: {
    alignItems: 'center',
    gap: 3,
    justifyContent: 'center',
    minWidth: 48,
    padding: 4,
  },
  tabLabel: {
    color: colors.textMuted,
    fontSize: 9,
  },
  tabSpacer: {
    flex: 1,
  },
  startButton: {
    alignItems: 'center',
    backgroundColor: colors.cyan,
    borderRadius: radii.md,
    flexDirection: 'row',
    gap: 6,
    height: 44,
    justifyContent: 'center',
    minWidth: 132,
    paddingHorizontal: spacing.md,
  },
  stopButton: {
    backgroundColor: colors.coral,
  },
  startLabel: {
    color: colors.canvas,
    fontFamily: fontFamilies.displayStrong,
    fontSize: 12,
    letterSpacing: 0.25,
  },
  pressed: {
    opacity: 0.76,
    transform: [{ scale: 0.98 }],
  },
});

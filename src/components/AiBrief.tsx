import { Sparkles } from 'lucide-react-native';
import { BlurView } from 'expo-blur';
import { StyleSheet, Text, View } from 'react-native';

import { getDataNatureLabel } from '../core/provenance';
import type { RouteOption } from '../data/catalog';
import { colors, fontFamilies, radii, spacing } from '../design/tokens';

interface AiBriefProps {
  route: RouteOption;
  isNavigating: boolean;
}

export function AiBrief({ route, isNavigating }: AiBriefProps) {
  return (
    <BlurView intensity={26} tint="dark" style={styles.panel}>
      <View style={styles.iconBox}>
        <Sparkles color={colors.amber} size={16} strokeWidth={1.8} />
      </View>
      <View style={styles.copy}>
        <View style={styles.titleRow}>
          <Text style={styles.title}>{isNavigating ? '航行状态' : 'AI 航路预判'}</Text>
          <View style={styles.pill}>
            <Text style={styles.pillText}>{getDataNatureLabel(route.provenance.nature)}</Text>
          </View>
        </View>
        <Text style={styles.detail} numberOfLines={1}>
          {isNavigating ? `正在沿「${route.label}」推进 · 飞船信号稳定` : route.detail}
        </Text>
      </View>
      <View style={styles.signal}>
        <View style={[styles.signalBar, styles.signalBarShort]} />
        <View style={[styles.signalBar, styles.signalBarMedium]} />
        <View style={[styles.signalBar, styles.signalBarTall]} />
      </View>
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
    minHeight: 54,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.sm,
  },
  iconBox: {
    alignItems: 'center',
    backgroundColor: 'rgba(247, 201, 137, 0.14)',
    borderRadius: radii.sm,
    height: 30,
    justifyContent: 'center',
    width: 30,
  },
  copy: {
    flex: 1,
    minWidth: 0,
  },
  titleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
  },
  title: {
    color: colors.text,
    fontSize: 11,
    fontWeight: '700',
  },
  pill: {
    backgroundColor: 'rgba(143, 226, 181, 0.13)',
    borderRadius: radii.pill,
    paddingHorizontal: 5,
    paddingVertical: 2,
  },
  pillText: {
    color: colors.green,
    fontFamily: fontFamilies.display,
    fontSize: 8,
    letterSpacing: 0.5,
  },
  detail: {
    color: colors.textMuted,
    fontSize: 10,
    marginTop: 4,
  },
  signal: {
    alignItems: 'flex-end',
    flexDirection: 'row',
    gap: 2,
    height: 17,
    paddingBottom: 1,
    width: 17,
  },
  signalBar: {
    backgroundColor: colors.cyan,
    borderRadius: radii.pill,
    width: 3,
  },
  signalBarShort: {
    height: 5,
  },
  signalBarMedium: {
    height: 10,
  },
  signalBarTall: {
    height: 15,
  },
});

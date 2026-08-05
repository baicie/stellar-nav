import { Gauge, ShieldCheck, Zap } from 'lucide-react-native';
import { ScrollView, StyleSheet, Text, Pressable, View } from 'react-native';

import { estimateRoute } from '../core/navigation';
import { formatDistance, formatDuration, formatFuel, formatRisk } from '../core/formatters';
import { getDataNatureLabel } from '../core/provenance';
import type { Destination } from '../data/catalog';
import { DEFAULT_VESSEL } from '../data/catalog';
import { colors, fontFamilies, radii, spacing } from '../design/tokens';

interface RouteRailProps {
  destination: Destination;
  selectedRouteId: string;
  onSelect: (routeId: string) => void;
  compact: boolean;
}

const accentColor = {
  cyan: colors.cyan,
  amber: colors.amber,
  coral: colors.coral,
} as const;

const routeIcon = {
  balanced: ShieldCheck,
  fastest: Zap,
  safest: Gauge,
} as const;

export function RouteRail({ destination, selectedRouteId, onSelect, compact }: RouteRailProps) {
  const selectedRoute =
    destination.routes.find((route) => route.id === selectedRouteId) ?? destination.routes[0]!;
  const selectedMetrics = estimateRoute(selectedRoute, DEFAULT_VESSEL.profile);
  const natureLabel = getDataNatureLabel(selectedRoute.provenance.nature);

  return (
    <View style={styles.wrapper}>
      <View style={styles.headingRow}>
        <Text style={styles.heading}>航路方案</Text>
        <Text style={styles.hint}>选择你的麻烦程度</Text>
      </View>
      <ScrollView
        accessibilityLabel="航路方案列表"
        accessibilityRole="tablist"
        contentContainerStyle={styles.content}
        horizontal
        showsHorizontalScrollIndicator={false}
      >
        {destination.routes.map((route) => {
          const metrics = estimateRoute(route, DEFAULT_VESSEL.profile);
          const selected = selectedRouteId === route.id;
          const Icon = routeIcon[route.strategy];
          const accent = accentColor[route.accent];

          return (
            <Pressable
              accessibilityRole="tab"
              accessibilityLabel={`${route.label}航线，${route.summary}`}
              accessibilityState={{ selected }}
              key={route.id}
              onPress={() => onSelect(route.id)}
              style={({ pressed }) => [
                styles.card,
                compact && styles.cardCompact,
                { borderColor: selected ? accent : colors.line },
                selected && { backgroundColor: `${accent}1F` },
                pressed && styles.pressed,
              ]}
            >
              <View style={styles.cardTop}>
                <View style={[styles.iconBox, { backgroundColor: `${accent}24` }]}>
                  <Icon color={accent} size={14} strokeWidth={2} />
                </View>
                <Text
                  style={[styles.routeLabel, { color: selected ? colors.text : colors.textMuted }]}
                >
                  {route.label}
                </Text>
                {selected && <View style={[styles.selectedDot, { backgroundColor: accent }]} />}
              </View>
              <Text style={styles.distance} numberOfLines={1}>
                {formatDistance(metrics.distanceLy)}
              </Text>
              <Text style={styles.duration} numberOfLines={1}>
                {formatDuration(metrics.estimatedYears)}
              </Text>
              <Text style={[styles.badge, { color: accent }]} numberOfLines={1}>
                {route.badge}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>
      <View
        accessibilityLabel={`当前${selectedRoute.label}航线，${natureLabel}估算，燃料${formatFuel(selectedMetrics.fuelUnits)}，风险${formatRisk(selectedMetrics.riskScore)}`}
        accessibilityRole="summary"
        style={[styles.metricsSummary, compact && styles.metricsSummaryCompact]}
      >
        <View style={styles.naturePill}>
          <Text style={styles.natureText}>{natureLabel}估算</Text>
        </View>
        <View style={styles.metric}>
          <Text style={styles.metricLabel}>燃料</Text>
          <Text style={styles.metricValue}>{formatFuel(selectedMetrics.fuelUnits)}</Text>
        </View>
        <View style={styles.metricDivider} />
        <View style={styles.metric}>
          <Text style={styles.metricLabel}>风险</Text>
          <Text style={styles.metricValue}>{formatRisk(selectedMetrics.riskScore)}</Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    paddingTop: spacing.sm,
  },
  headingRow: {
    alignItems: 'baseline',
    flexDirection: 'row',
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
  },
  heading: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '700',
  },
  hint: {
    color: colors.textQuiet,
    fontSize: 10,
  },
  content: {
    gap: spacing.sm,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm,
  },
  metricsSummary: {
    alignItems: 'center',
    backgroundColor: 'rgba(8, 18, 26, 0.78)',
    borderColor: colors.line,
    borderRadius: radii.sm,
    borderWidth: 1,
    flexDirection: 'row',
    gap: spacing.sm,
    height: 30,
    marginBottom: spacing.xs,
    marginHorizontal: spacing.lg,
    paddingHorizontal: spacing.sm,
  },
  metricsSummaryCompact: {
    height: 28,
  },
  naturePill: {
    backgroundColor: 'rgba(143, 226, 181, 0.12)',
    borderRadius: radii.pill,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  natureText: {
    color: colors.green,
    fontFamily: fontFamilies.display,
    fontSize: 8,
  },
  metric: {
    alignItems: 'baseline',
    flexDirection: 'row',
    gap: spacing.xs,
  },
  metricLabel: {
    color: colors.textQuiet,
    fontSize: 8,
  },
  metricValue: {
    color: colors.text,
    fontFamily: fontFamilies.display,
    fontSize: 10,
  },
  metricDivider: {
    backgroundColor: colors.line,
    height: 12,
    width: 1,
  },
  card: {
    backgroundColor: 'rgba(8, 18, 26, 0.78)',
    borderRadius: radii.md,
    borderWidth: 1,
    height: 102,
    padding: spacing.sm,
    width: 122,
  },
  cardCompact: {
    height: 94,
  },
  pressed: {
    opacity: 0.76,
    transform: [{ translateY: 1 }],
  },
  cardTop: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 6,
  },
  iconBox: {
    alignItems: 'center',
    borderRadius: radii.sm,
    height: 23,
    justifyContent: 'center',
    width: 23,
  },
  routeLabel: {
    fontSize: 12,
    fontWeight: '700',
  },
  selectedDot: {
    borderRadius: radii.pill,
    height: 5,
    marginLeft: 'auto',
    width: 5,
  },
  distance: {
    color: colors.text,
    fontFamily: fontFamilies.displayStrong,
    fontSize: 15,
    marginTop: 8,
  },
  duration: {
    color: colors.textMuted,
    fontFamily: fontFamilies.display,
    fontSize: 10,
    marginTop: 1,
  },
  badge: {
    fontSize: 9,
    fontWeight: '700',
    marginTop: 'auto',
  },
});

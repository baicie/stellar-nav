import { AlertTriangle } from 'lucide-react-native';
import { StyleSheet, Text, View } from 'react-native';

import { colors, radii, spacing } from '../design/tokens';

export function StartupErrorScreen() {
  return (
    <View accessibilityRole="alert" style={styles.screen}>
      <View style={styles.iconBox}>
        <AlertTriangle color={colors.amber} size={24} strokeWidth={1.8} />
      </View>
      <Text style={styles.title}>星图引擎未就绪</Text>
      <Text style={styles.message}>本地绘图组件加载失败，请刷新页面后重试。</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    alignItems: 'center',
    backgroundColor: colors.canvas,
    flex: 1,
    justifyContent: 'center',
    padding: spacing.xl,
  },
  iconBox: {
    alignItems: 'center',
    backgroundColor: 'rgba(247, 201, 137, 0.1)',
    borderColor: 'rgba(247, 201, 137, 0.28)',
    borderRadius: radii.md,
    borderWidth: 1,
    height: 48,
    justifyContent: 'center',
    width: 48,
  },
  title: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
    marginTop: spacing.md,
  },
  message: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 20,
    marginTop: spacing.sm,
    maxWidth: 320,
    textAlign: 'center',
  },
});

import { Check, X } from 'lucide-react-native';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';

import { colors, fontFamilies, radii, spacing } from '../design/tokens';
import type { MapLayerId, MapLayerVisibility } from '../renderer/layers';

interface LayerSheetProps {
  visible: boolean;
  enabledLayers: MapLayerVisibility;
  onToggle: (layerId: MapLayerId) => void;
  onClose: () => void;
}

const layerOptions: readonly {
  id: MapLayerId;
  name: string;
  detail: string;
  color: string;
}[] = [
  {
    id: 'stars',
    name: '星野与目的地',
    detail: '程序化背景与地图位置 · 设定；天体目录 · 推导',
    color: colors.cyan,
  },
  { id: 'routes', name: '航线轨迹', detail: '确定性路线模型 · 模拟', color: colors.mint },
  { id: 'hazards', name: '引力异常区', detail: '世界观警戒层 · 设定', color: colors.coral },
] as const;

export function LayerSheet({ visible, enabledLayers, onToggle, onClose }: LayerSheetProps) {
  return (
    <Modal animationType="fade" onRequestClose={onClose} transparent visible={visible}>
      <Pressable accessibilityLabel="关闭星图图层" onPress={onClose} style={styles.backdrop}>
        <View onStartShouldSetResponder={() => true} style={styles.sheet}>
          <View style={styles.header}>
            <View>
              <Text style={styles.eyebrow}>显示设置</Text>
              <Text style={styles.title}>星图图层</Text>
            </View>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="关闭星图图层"
              onPress={onClose}
              style={styles.close}
            >
              <X color={colors.textMuted} size={18} strokeWidth={1.8} />
            </Pressable>
          </View>
          <View style={styles.list}>
            {layerOptions.map((layer) => {
              const checked = enabledLayers[layer.id] ?? false;
              return (
                <Pressable
                  accessibilityRole="switch"
                  accessibilityState={{ checked }}
                  accessibilityLabel={`切换${layer.name}`}
                  key={layer.id}
                  onPress={() => onToggle(layer.id)}
                  style={({ pressed }) => [styles.row, pressed && styles.pressed]}
                >
                  <View style={[styles.colorDot, { backgroundColor: layer.color }]} />
                  <View style={styles.copy}>
                    <Text style={styles.name}>{layer.name}</Text>
                    <Text style={styles.detail}>{layer.detail}</Text>
                  </View>
                  <View
                    style={[
                      styles.checkbox,
                      checked && { backgroundColor: layer.color, borderColor: layer.color },
                    ]}
                  >
                    {checked && <Check color={colors.canvas} size={14} strokeWidth={2.4} />}
                  </View>
                </Pressable>
              );
            })}
          </View>
          <Text style={styles.footnote}>渲染层在本地运行，切换不会改变路线计算。</Text>
        </View>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    alignItems: 'flex-end',
    backgroundColor: 'rgba(0, 0, 0, 0.48)',
    flex: 1,
    justifyContent: 'flex-start',
    paddingHorizontal: spacing.lg,
    paddingTop: 116,
  },
  sheet: {
    backgroundColor: colors.canvasRaised,
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    maxWidth: 360,
    padding: spacing.lg,
    width: '100%',
  },
  header: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  eyebrow: {
    color: colors.cyan,
    fontFamily: fontFamilies.display,
    fontSize: 9,
    letterSpacing: 0.7,
  },
  title: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '700',
    marginTop: 3,
  },
  close: {
    alignItems: 'center',
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    height: 34,
    justifyContent: 'center',
    width: 34,
  },
  list: {
    gap: spacing.xs,
    marginTop: spacing.lg,
  },
  row: {
    alignItems: 'center',
    flexDirection: 'row',
    minHeight: 48,
  },
  pressed: {
    opacity: 0.72,
  },
  colorDot: {
    borderRadius: radii.pill,
    height: 8,
    width: 8,
  },
  copy: {
    flex: 1,
    marginLeft: spacing.md,
  },
  name: {
    color: colors.text,
    fontSize: 12,
    fontWeight: '700',
  },
  detail: {
    color: colors.textMuted,
    fontSize: 10,
    marginTop: 2,
  },
  checkbox: {
    alignItems: 'center',
    borderColor: colors.line,
    borderRadius: radii.sm,
    borderWidth: 1,
    height: 22,
    justifyContent: 'center',
    width: 22,
  },
  footnote: {
    color: colors.textQuiet,
    fontSize: 9,
    marginTop: spacing.md,
  },
});

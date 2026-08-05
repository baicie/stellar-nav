import type { ComponentType } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { colors, radii } from '../design/tokens';

type IconProps = {
  color?: string;
  size?: number;
  strokeWidth?: number;
};

interface IconButtonProps {
  icon: ComponentType<IconProps>;
  label: string;
  onPress?: () => void;
  active?: boolean;
  disabled?: boolean;
  tone?: 'neutral' | 'cyan' | 'coral';
}

export function IconButton({
  icon: Icon,
  label,
  onPress,
  active = false,
  disabled = false,
  tone = 'neutral',
}: IconButtonProps) {
  const tint =
    tone === 'coral' ? colors.coral : tone === 'cyan' || active ? colors.cyan : colors.text;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled, selected: active }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.button,
        active && styles.active,
        pressed && styles.pressed,
        disabled && styles.disabled,
      ]}
    >
      <View style={styles.iconPassthrough}>
        <Icon color={tint} size={18} strokeWidth={1.8} />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: {
    alignItems: 'center',
    backgroundColor: colors.glassSoft,
    borderColor: colors.line,
    borderRadius: radii.md,
    borderWidth: 1,
    height: 38,
    justifyContent: 'center',
    width: 38,
  },
  iconPassthrough: {
    pointerEvents: 'none',
  },
  active: {
    backgroundColor: 'rgba(83, 221, 234, 0.14)',
    borderColor: 'rgba(83, 221, 234, 0.58)',
  },
  pressed: {
    opacity: 0.72,
    transform: [{ scale: 0.96 }],
  },
  disabled: {
    opacity: 0.45,
  },
});

import { ActivityIndicator, Pressable, StyleSheet, Text, type StyleProp, type ViewStyle } from 'react-native';
import * as Haptics from 'expo-haptics';
import { colors, fonts, radius, touch } from '@/theme';

type Variant = 'dark' | 'lime' | 'blue' | 'ghost' | 'ghostLight';

type Props = {
  label: string;
  onPress?: () => void;
  variant?: Variant;
  small?: boolean;
  style?: StyleProp<ViewStyle>;
  disabled?: boolean;
  // Muestra un indicador y bloquea el botón mientras se envía
  cargando?: boolean;
};

const palette: Record<Variant, { bg: string; fg: string; border: string }> = {
  dark: { bg: colors.ink, fg: colors.white, border: colors.ink },
  lime: { bg: colors.lime, fg: colors.ink, border: colors.lime },
  blue: { bg: colors.blue, fg: colors.white, border: colors.blue },
  ghost: { bg: 'transparent', fg: colors.ink, border: colors.ink },
  ghostLight: { bg: 'transparent', fg: colors.white, border: colors.white },
};

export function Button({ label, onPress, variant = 'dark', small, style, disabled, cargando }: Props) {
  const p = palette[variant];
  const bloqueado = disabled || cargando;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ disabled: !!bloqueado, busy: !!cargando }}
      disabled={bloqueado}
      onPress={() => {
        Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
        onPress?.();
      }}
      style={({ pressed }) => [
        styles.base,
        small && styles.small,
        { backgroundColor: p.bg, borderColor: p.border, opacity: disabled ? 0.5 : pressed ? 0.85 : 1 },
        style,
      ]}
    >
      {cargando ? (
        <ActivityIndicator color={p.fg} />
      ) : (
        <Text style={[styles.label, small && styles.labelSmall, { color: p.fg }]}>{label}</Text>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    minHeight: touch.btn,
    paddingHorizontal: 20,
    borderRadius: radius.btn,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  small: { minHeight: touch.min, paddingHorizontal: 14, borderRadius: 12 },
  label: { fontFamily: fonts.bodyBold, fontSize: 18 },
  labelSmall: { fontSize: 15 },
});

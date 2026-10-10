import { useEffect, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import Animated, { Easing, useAnimatedStyle, useReducedMotion, useSharedValue, withDelay, withTiming } from 'react-native-reanimated';
import { colors, fonts } from '@/theme';

// Aparece con un pequeño rebote, una sola vez (respeta "reducir movimiento")
export function Pop({ delay = 0, style, children }: { delay?: number; style?: StyleProp<ViewStyle>; children: ReactNode }) {
  const reducido = useReducedMotion();
  const v = useSharedValue(reducido ? 1 : 0);
  useEffect(() => {
    if (!reducido) v.value = withDelay(delay, withTiming(1, { duration: 420, easing: Easing.out(Easing.back(1.6)) }));
  }, [delay, reducido, v]);
  const anim = useAnimatedStyle(() => ({ opacity: v.value, transform: [{ scale: 0.4 + 0.6 * v.value }] }));
  return <Animated.View style={[style, anim]}>{children}</Animated.View>;
}

// Ficha flotante sobre el avatar (nivel, racha, premios…)
export function Ficha({
  children, onPress, etiqueta, fondo = 'rgba(15,29,46,0.86)', ancho = 76, alto = 76,
}: {
  children: ReactNode; onPress?: () => void; etiqueta: string; fondo?: string; ancho?: number; alto?: number;
}) {
  const estilo = [styles.ficha, { backgroundColor: fondo, width: ancho, minHeight: alto }];
  if (!onPress) {
    return (
      <View style={estilo} accessible accessibilityLabel={etiqueta}>
        {children}
      </View>
    );
  }
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={etiqueta} onPress={onPress} style={estilo}>
      {children}
    </Pressable>
  );
}

export function BarraXp({ valor, claro }: { valor: number; claro?: boolean }) {
  return (
    <View style={[styles.barra, { backgroundColor: claro ? colors.line : '#2B3C52' }]} accessibilityRole="progressbar" accessibilityValue={{ min: 0, max: 100, now: Math.round(valor * 100) }}>
      <View style={[styles.relleno, { width: `${Math.max(2, Math.min(1, valor) * 100)}%`, backgroundColor: claro ? colors.blue : colors.lime }]} />
    </View>
  );
}

export const textoClase = StyleSheet.create({
  etiqueta: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, textTransform: 'uppercase' },
});

const styles = StyleSheet.create({
  ficha: { borderRadius: 20, alignItems: 'center', justifyContent: 'center', gap: 2, padding: 6 },
  barra: { height: 10, borderRadius: 99, overflow: 'hidden' },
  relleno: { height: '100%', borderRadius: 99 },
});

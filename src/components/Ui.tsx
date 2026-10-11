import type { ReactNode } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View, type StyleProp, type ViewStyle } from 'react-native';
import * as Haptics from 'expo-haptics';
import { colors, fonts, touch } from '@/theme';

export function Card({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

// Mensaje de error o de información, anunciado por el lector de pantalla
export function Aviso({ texto, tipo = 'error' }: { texto: string | null; tipo?: 'error' | 'info' }) {
  if (!texto) return null;
  const error = tipo === 'error';
  return (
    <View
      accessibilityRole="alert"
      accessibilityLiveRegion="polite"
      style={[styles.aviso, { backgroundColor: error ? colors.orangeLight : colors.blueLight }]}
    >
      <Text style={[styles.avisoText, { color: error ? colors.orangeDark : colors.blueDark }]}>{texto}</Text>
    </View>
  );
}

type TagTipo = 'azul' | 'lima' | 'naranja' | 'tinta';
const tagColores: Record<TagTipo, { bg: string; fg: string }> = {
  azul: { bg: colors.blueLight, fg: colors.blueDark },
  lima: { bg: colors.lime, fg: colors.ink },
  naranja: { bg: colors.orangeLight, fg: colors.orangeDark },
  tinta: { bg: colors.ink, fg: colors.white },
};

export function Tag({ texto, tipo = 'azul' }: { texto: string; tipo?: TagTipo }) {
  const c = tagColores[tipo];
  return (
    <View style={[styles.tag, { backgroundColor: c.bg }]}>
      <Text style={[styles.tagText, { color: c.fg }]}>{texto}</Text>
    </View>
  );
}

export function Chip({ texto, on, onPress, etiqueta }: { texto: string; on?: boolean; onPress: () => void; etiqueta?: string }) {
  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityLabel={etiqueta ?? texto}
      accessibilityState={{ selected: !!on }}
      onPress={() => {
        Haptics.selectionAsync().catch(() => {});
        onPress();
      }}
      style={[styles.chip, on && styles.chipOn]}
    >
      <Text style={[styles.chipText, on && { color: colors.white }]}>{texto}</Text>
    </Pressable>
  );
}

// Iniciales sobre un círculo de color (avatar de escuela o persona)
export function Iniciales({ nombre, color = colors.blue }: { nombre: string; color?: string }) {
  const ini = nombre
    .split(/\s+/)
    .filter((p) => p.length > 2 || nombre.split(/\s+/).length === 1)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase())
    .join('');
  return (
    <View style={[styles.av, { backgroundColor: color }]} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <Text style={styles.avText}>{ini || '·'}</Text>
    </View>
  );
}

export function Cargando() {
  return (
    <View style={styles.cargando} accessibilityLabel="Cargando">
      <ActivityIndicator color={colors.blue} />
    </View>
  );
}

const styles = StyleSheet.create({
  card: { backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line, borderRadius: 20, padding: 16, gap: 12 },
  aviso: { borderRadius: 14, padding: 14 },
  avisoText: { fontFamily: fonts.bodySemi, fontSize: 15 },
  tag: { height: 26, paddingHorizontal: 10, borderRadius: 999, justifyContent: 'center', alignSelf: 'flex-start' },
  tagText: { fontFamily: fonts.bodyBold, fontSize: 12 },
  chip: {
    minHeight: touch.min,
    paddingHorizontal: 16,
    borderRadius: 999,
    borderWidth: 2,
    borderColor: colors.line,
    backgroundColor: colors.white,
    justifyContent: 'center',
  },
  chipOn: { backgroundColor: colors.ink, borderColor: colors.ink },
  chipText: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.ink },
  av: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
  avText: { fontFamily: fonts.bodyHeavy, fontSize: 16, color: colors.white },
  cargando: { paddingVertical: 32, alignItems: 'center' },
});

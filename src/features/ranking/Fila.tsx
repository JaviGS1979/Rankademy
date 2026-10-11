import type { ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { colors, fonts } from '@/theme';

type Props = {
  posicion: number;
  izquierda: ReactNode;
  titulo: string;
  subtitulo?: string | null;
  puntos: number;
  unidad?: string;
  mio?: boolean;
  onPress?: () => void;
};

// 1.240 (con punto desde los miles, como en el diseño)
export const formato = (n: number) => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');

// Una fila de ranking: posición, avatar o iniciales, nombre, escuela y puntos. La mía va resaltada.
export function FilaRanking({ posicion, izquierda, titulo, subtitulo, puntos, unidad = 'pts', mio, onPress }: Props) {
  const Contenedor = onPress ? Pressable : View;
  return (
    <Contenedor
      {...(onPress ? { accessibilityRole: 'button' as const, onPress } : {})}
      accessibilityLabel={`Puesto ${posicion}, ${titulo}${mio ? ' (tú)' : ''}${subtitulo ? `, ${subtitulo}` : ''}, ${formato(puntos)} ${unidad}`}
      accessible
      style={[styles.fila, mio && styles.mia]}
    >
      <Text style={[styles.pos, posicion <= 3 && { color: colors.ink }]}>{posicion}</Text>
      {izquierda}
      <View style={{ flex: 1, gap: 1 }}>
        <Text style={styles.nombre} numberOfLines={2}>
          {titulo}
          {mio ? ' (tú)' : ''}
        </Text>
        {!!subtitulo && <Text style={styles.sub} numberOfLines={1}>{subtitulo}</Text>}
      </View>
      <View style={{ alignItems: 'flex-end' }}>
        <Text style={styles.puntos}>{formato(puntos)}</Text>
        <Text style={styles.unidad}>{unidad}</Text>
      </View>
    </Contenedor>
  );
}

export function Separador() {
  return (
    <Text style={styles.separador} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      ···
    </Text>
  );
}

const styles = StyleSheet.create({
  fila: {
    flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 64, paddingHorizontal: 12, paddingVertical: 8,
    borderRadius: 16, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.card,
  },
  mia: { backgroundColor: colors.lime, borderColor: colors.lime },
  pos: { width: 32, textAlign: 'center', fontFamily: fonts.display, fontSize: 30, color: colors.ink2 },
  nombre: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  sub: { fontFamily: fonts.body, fontSize: 13, color: colors.ink2 },
  puntos: { fontFamily: fonts.display, fontSize: 28, color: colors.ink },
  unidad: { fontFamily: fonts.bodySemi, fontSize: 11, color: colors.ink2, marginTop: -4 },
  separador: { textAlign: 'center', fontFamily: fonts.bodyBold, fontSize: 18, color: colors.ink2, lineHeight: 14 },
});

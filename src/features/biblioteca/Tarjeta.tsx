import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Icon, Tag } from '@/components';
import type { ResumenEjercicio } from '@/lib/tipos';
import { colors, fonts } from '@/theme';
import { textoEdad, textoJugadores } from './constantes';
import { Pista } from './Pista';

type Props = { e: ResumenEjercicio; onPress: () => void; ancho?: number | string; seleccionada?: boolean };

// Tarjeta de la cuadrícula: dibujo, nombre, edad y jugadores
export function Tarjeta({ e, onPress, ancho = '48%', seleccionada }: Props) {
  const edad = textoEdad(e.edad_min, e.edad_max);
  return (
    <Pressable
      accessibilityRole={seleccionada === undefined ? 'button' : 'checkbox'}
      accessibilityState={seleccionada === undefined ? undefined : { checked: seleccionada }}
      accessibilityLabel={`${e.titulo}, ${edad ? `${edad} años, ` : ''}${textoJugadores(e.jugadores_min, e.jugadores_max)}`}
      onPress={onPress}
      style={({ pressed }) => [styles.tarjeta, { width: ancho as never }, pressed && { opacity: 0.85 }, e.retirado && { opacity: 0.6 }, seleccionada && styles.sel]}
    >
      <View>
        <Pista elementos={e.dibujo ?? []} miniatura style={{ borderRadius: 0 }} />
        {seleccionada && (
          <View style={styles.check}>
            <Icon name="check" color={colors.ink} strokeWidth={3} size={20} />
          </View>
        )}
        <View style={styles.insignias}>
          {e.variantes > 0 && <Tag texto={e.variantes === 1 ? '1 variante' : `${e.variantes} variantes`} tipo="lima" />}
          {e.imagenes > 1 && <Tag texto={`${e.imagenes} imágenes`} tipo="tinta" />}
        </View>
      </View>
      <View style={{ padding: 10, gap: 6 }}>
        <Text style={styles.titulo} numberOfLines={2}>{e.titulo}</Text>
        <View style={styles.meta}>
          {!!edad && <Tag texto={edad} tipo="azul" />}
          <Text style={styles.mut}>{textoJugadores(e.jugadores_min, e.jugadores_max)}</Text>
        </View>
        {(e.retirado || e.visibilidad === 'escuela' || e.original_id) && (
          <View style={styles.meta}>
            {e.retirado && <Tag texto="Retirado" tipo="naranja" />}
            {e.visibilidad === 'escuela' && <Tag texto="Solo mi escuela" tipo="tinta" />}
            {e.original_id && <Tag texto="Variante" tipo="azul" />}
          </View>
        )}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  tarjeta: { backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line, borderRadius: 18, overflow: 'hidden' },
  sel: { borderColor: colors.lime, borderWidth: 3 },
  check: { position: 'absolute', right: 6, bottom: 6, width: 32, height: 32, borderRadius: 16, backgroundColor: colors.lime, alignItems: 'center', justifyContent: 'center', zIndex: 2 },
  insignias: { position: 'absolute', top: 6, left: 6, right: 6, flexDirection: 'row', flexWrap: 'wrap', gap: 4 },
  titulo: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink, lineHeight: 20 },
  meta: { flexDirection: 'row', alignItems: 'center', flexWrap: 'wrap', gap: 6 },
  mut: { fontFamily: fonts.bodySemi, fontSize: 13, color: colors.ink2 },
});

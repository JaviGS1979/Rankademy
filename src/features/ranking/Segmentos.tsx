import { Pressable, StyleSheet, Text, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { colors, fonts } from '@/theme';

type Props<T extends string> = {
  opciones: { id: T; label: string }[];
  valor: T;
  onChange: (v: T) => void;
  // Texto más pequeño cuando hay cuatro opciones
  compacto?: boolean;
};

// Control segmentado (Alumnos · Entrenadores · Escuelas, Mi escuela · Provincia…)
export function Segmentos<T extends string>({ opciones, valor, onChange, compacto }: Props<T>) {
  return (
    <View style={styles.caja} accessibilityRole="radiogroup">
      {opciones.map((o) => (
        <Pressable
          key={o.id}
          accessibilityRole="radio"
          accessibilityState={{ selected: o.id === valor }}
          onPress={() => {
            Haptics.selectionAsync().catch(() => {});
            onChange(o.id);
          }}
          style={[styles.op, o.id === valor && styles.opOn]}
        >
          <Text style={[styles.texto, compacto && { fontSize: 13 }, o.id === valor && { color: colors.ink }]} numberOfLines={1}>
            {o.label}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  caja: { flexDirection: 'row', backgroundColor: '#E3E8EE', borderRadius: 14, padding: 4, gap: 2 },
  op: { flex: 1, minHeight: 44, borderRadius: 11, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 4 },
  opOn: { backgroundColor: colors.white },
  texto: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink2 },
});

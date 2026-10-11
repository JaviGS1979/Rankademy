import { Pressable, StyleSheet, Text, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { colors, fonts } from '@/theme';

type Props = { label: string; value: number; min: number; max: number; onChange: (v: number) => void };

// Número con botones − y +
export function Stepper({ label, value, min, max, onChange }: Props) {
  const cambia = (d: number) => {
    const v = Math.min(max, Math.max(min, value + d));
    if (v !== value) {
      Haptics.selectionAsync().catch(() => {});
      onChange(v);
    }
  };
  return (
    <View style={styles.caja} accessible accessibilityRole="adjustable" accessibilityLabel={label} accessibilityValue={{ now: value, min, max }}
      accessibilityActions={[{ name: 'increment' }, { name: 'decrement' }]}
      onAccessibilityAction={(e) => cambia(e.nativeEvent.actionName === 'increment' ? 1 : -1)}>
      <Pressable accessibilityLabel={`Menos ${label}`} onPress={() => cambia(-1)} style={styles.boton} hitSlop={4}>
        <Text style={styles.signo}>−</Text>
      </Pressable>
      <Text style={styles.valor}>{value}</Text>
      <Pressable accessibilityLabel={`Más ${label}`} onPress={() => cambia(1)} style={styles.boton} hitSlop={4}>
        <Text style={styles.signo}>+</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  caja: { flexDirection: 'row', alignItems: 'center', borderWidth: 2, borderColor: colors.line, borderRadius: 14, backgroundColor: colors.white, height: 56 },
  boton: { width: 48, height: 52, alignItems: 'center', justifyContent: 'center' },
  signo: { fontFamily: fonts.bodyBold, fontSize: 24, color: colors.ink },
  valor: { minWidth: 36, textAlign: 'center', fontFamily: fonts.display, fontSize: 28, color: colors.ink },
});

import { ScrollView, StyleSheet } from 'react-native';
import { Chip } from '@/components';
import { useEscuela } from '@/lib/escuela';

// Si la persona está en varias escuelas, deja elegir cuál ver
export function SelectorEscuela() {
  const { escuelas, actual, elegir } = useEscuela();
  if (escuelas.length < 2) return null;
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.fila} accessibilityRole="radiogroup">
      {escuelas.map((e) => (
        <Chip key={e.id} texto={e.nombre} on={e.id === actual?.id} onPress={() => elegir(e.id)} />
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({ fila: { gap: 8, paddingVertical: 2 } });

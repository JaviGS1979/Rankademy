import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import * as Haptics from 'expo-haptics';
import type { Elemento, Punto } from '@/lib/tipos';
import { colors, fonts } from '@/theme';
import { MAX_ELEMENTOS } from './constantes';
import { PISTA_H, PISTA_W, Pista } from './Pista';

type Herramienta = 'jugador' | 'pelota' | 'cono' | 'bola' | 'carrera';

const HERRAMIENTAS: { id: Herramienta; label: string; ayuda: string }[] = [
  { id: 'jugador', label: 'Jugador', ayuda: 'Toca la pista para poner un jugador.' },
  { id: 'pelota', label: 'Pelota', ayuda: 'Toca la pista para poner una pelota.' },
  { id: 'cono', label: 'Cono', ayuda: 'Toca la pista para poner un cono.' },
  { id: 'bola', label: 'Trayecto de bola', ayuda: 'Toca dónde sale la bola y después dónde llega.' },
  { id: 'carrera', label: 'Carrera', ayuda: 'Toca dónde sale el jugador y después dónde llega.' },
];

const redondea = (n: number) => Math.round(n * 10) / 10;

type Props = {
  elementos: Elemento[];
  onChange: (e: Elemento[]) => void;
};

// Dibujar el ejercicio: se elige una herramienta y se toca la pista.
// Un trayecto se hace con dos toques (salida y llegada).
export function PistaEditor({ elementos, onChange }: Props) {
  const [herramienta, setHerramienta] = useState<Herramienta>('jugador');
  const [ancho, setAncho] = useState(0);
  const [alto, setAlto] = useState(0);
  const [salida, setSalida] = useState<Punto | null>(null);
  const lleno = elementos.length >= MAX_ELEMENTOS;

  const tocar = (px: number, py: number) => {
    if (!ancho || !alto) return;
    const x = redondea(Math.min(PISTA_W, Math.max(0, (px / ancho) * PISTA_W)));
    const y = redondea(Math.min(PISTA_H, Math.max(0, (py / alto) * PISTA_H)));
    if (herramienta === 'bola' || herramienta === 'carrera') {
      if (!salida) {
        setSalida([x, y]);
        Haptics.selectionAsync().catch(() => {});
        return;
      }
      if (lleno) return;
      onChange([...elementos, { t: 'trayecto', de: salida, a: [x, y], tipo: herramienta }]);
      setSalida(null);
    } else {
      if (lleno) return;
      onChange([...elementos, { t: herramienta, x, y }]);
    }
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
  };

  const gesto = Gesture.Tap()
    .runOnJS(true)
    .onEnd((e, ok) => {
      if (ok) tocar(e.x, e.y);
    });

  const elegir = (h: Herramienta) => {
    setHerramienta(h);
    setSalida(null);
  };

  return (
    <View style={{ gap: 10 }}>
      <GestureDetector gesture={gesto}>
        <View
          onLayout={(e) => {
            setAncho(e.nativeEvent.layout.width);
            setAlto(e.nativeEvent.layout.height);
          }}
          accessibilityLabel="Pista para dibujar el ejercicio"
        >
          <Pista elementos={elementos} pendiente={salida} />
        </View>
      </GestureDetector>

      <View style={styles.fila} accessibilityRole="radiogroup">
        {HERRAMIENTAS.map((h) => (
          <Pressable
            key={h.id}
            accessibilityRole="radio"
            accessibilityState={{ selected: herramienta === h.id }}
            onPress={() => elegir(h.id)}
            style={[styles.herr, herramienta === h.id && styles.herrOn]}
          >
            <Text style={[styles.herrText, herramienta === h.id && { color: colors.white }]}>{h.label}</Text>
          </Pressable>
        ))}
      </View>

      <Text style={styles.ayuda}>
        {lleno ? `Máximo ${MAX_ELEMENTOS} elementos por imagen.` : salida ? 'Ahora toca dónde llega.' : HERRAMIENTAS.find((h) => h.id === herramienta)?.ayuda}
      </Text>

      <View style={styles.fila}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Deshacer lo último"
          disabled={elementos.length === 0 && !salida}
          onPress={() => (salida ? setSalida(null) : onChange(elementos.slice(0, -1)))}
          style={[styles.accion, elementos.length === 0 && !salida && { opacity: 0.4 }]}
        >
          <Text style={styles.accionText}>Deshacer</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Borrar todo el dibujo"
          disabled={elementos.length === 0}
          onPress={() => {
            setSalida(null);
            onChange([]);
          }}
          style={[styles.accion, elementos.length === 0 && { opacity: 0.4 }]}
        >
          <Text style={styles.accionText}>Borrar todo</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  herr: { minHeight: 44, paddingHorizontal: 16, borderRadius: 999, borderWidth: 2, borderColor: colors.line, backgroundColor: colors.white, justifyContent: 'center' },
  herrOn: { backgroundColor: colors.ink, borderColor: colors.ink },
  herrText: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.ink },
  ayuda: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  accion: { minHeight: 44, paddingHorizontal: 16, borderRadius: 12, borderWidth: 2, borderColor: colors.line, justifyContent: 'center', backgroundColor: colors.white },
  accionText: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
});

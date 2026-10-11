import { useCallback, useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useKeepAwake } from 'expo-keep-awake';
import * as Haptics from 'expo-haptics';
import { Aviso, Cargando, Icon } from '@/components';
import { detalleConCache } from '@/features/biblioteca/cache';
import { Pista } from '@/features/biblioteca/Pista';
import { mensajeError } from '@/lib/errores';
import type { DetalleEjercicio } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

// Modo pista: pantalla grande y oscura para usarla de pie en la pista, con la pantalla siempre encendida.
// Cada paso se muestra con su imagen (si hay menos imágenes que pasos, se queda la última).
export default function ModoPista() {
  useKeepAwake();
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [d, setD] = useState<DetalleEjercicio | null>(null);
  const [sinConexion, setSinConexion] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [i, setI] = useState(0);

  useEffect(() => {
    detalleConCache(id)
      .then((r) => {
        setD(r.detalle);
        setSinConexion(r.sinConexion);
      })
      .catch((e) => setError(mensajeError(e)));
  }, [id]);

  const total = d ? Math.max(d.imagenes.length, d.pasos.length, 1) : 1;
  const ultimo = i >= total - 1;
  const ir = useCallback(
    (delta: number) => {
      Haptics.selectionAsync().catch(() => {});
      setI((v) => Math.min(total - 1, Math.max(0, v + delta)));
    },
    [total],
  );

  return (
    <SafeAreaView style={styles.root}>
      <View style={styles.columna}>
        <View style={styles.cabecera}>
          <Pressable accessibilityRole="button" accessibilityLabel="Cerrar modo pista" onPress={() => router.back()} style={styles.cerrar}>
            <Icon name="close" color={colors.white} />
          </Pressable>
          <Text style={styles.titulo} numberOfLines={1} accessibilityRole="header">{d?.titulo ?? ''}</Text>
          {sinConexion && (
            <View style={styles.sinCon}>
              <Text style={styles.sinConText}>Sin conexión</Text>
            </View>
          )}
        </View>

        {!d && !error && <Cargando />}
        {error && <View style={{ padding: 20 }}><Aviso texto={error} /></View>}

        {d && (
          <>
            <View style={{ paddingHorizontal: 16 }}>
              <Pista elementos={d.imagenes[Math.min(i, d.imagenes.length - 1)] ?? []} etiqueta={`Imagen ${Math.min(i, d.imagenes.length - 1) + 1} de ${d.imagenes.length}`} />
              {d.imagenes.length > 1 && (
                <View style={styles.contador}>
                  <Text style={styles.contadorText}>{Math.min(i, d.imagenes.length - 1) + 1} / {d.imagenes.length}</Text>
                </View>
              )}
            </View>

            <View style={styles.pasos}>
              {d.pasos.length === 0 && <Text style={[styles.paso, { color: colors.white }]}>{d.titulo}</Text>}
              {d.pasos.map((p, n) => (
                <View key={n} style={[styles.pasoFila, n !== i && { opacity: 0.4 }]}>
                  <View style={[styles.num, n === i && { backgroundColor: colors.lime }]}>
                    <Text style={[styles.numText, n === i && { color: colors.ink }]}>{n + 1}</Text>
                  </View>
                  <Text style={styles.paso}>{p}</Text>
                </View>
              ))}
            </View>

            <View style={styles.botones}>
              <Pressable accessibilityRole="button" accessibilityLabel="Anterior" disabled={i === 0} onPress={() => ir(-1)} style={[styles.atras, i === 0 && { opacity: 0.35 }]}>
                <Icon name="back" color={colors.white} size={32} />
              </Pressable>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={ultimo ? 'Terminar' : 'Siguiente'}
                onPress={() => (ultimo ? router.back() : ir(1))}
                style={styles.sig}
              >
                <Text style={styles.sigText}>{ultimo ? 'Terminar' : 'Siguiente'}</Text>
                {!ultimo && <Icon name="next" color={colors.ink} size={28} />}
              </Pressable>
            </View>
          </>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.ink },
  columna: { flex: 1, width: '100%', maxWidth: 560, alignSelf: 'center', gap: 16, paddingBottom: 16 },
  cabecera: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingTop: 12 },
  cerrar: { width: 48, height: 48, borderRadius: 24, backgroundColor: '#1D3047', alignItems: 'center', justifyContent: 'center' },
  titulo: { flex: 1, fontFamily: fonts.display, fontSize: 24, color: colors.white, textTransform: 'uppercase' },
  sinCon: { backgroundColor: colors.lime, borderRadius: 999, paddingHorizontal: 10, height: 28, justifyContent: 'center' },
  sinConText: { fontFamily: fonts.bodyBold, fontSize: 12, color: colors.ink },
  contador: { position: 'absolute', top: 10, right: 26, backgroundColor: 'rgba(15,29,46,0.85)', borderRadius: 99, paddingHorizontal: 10, paddingVertical: 3 },
  contadorText: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.white },
  pasos: { flex: 1, justifyContent: 'center', gap: 14, paddingHorizontal: 20 },
  pasoFila: { flexDirection: 'row', alignItems: 'center', gap: 16 },
  num: { width: 52, height: 52, borderRadius: 26, backgroundColor: '#1D3047', alignItems: 'center', justifyContent: 'center' },
  numText: { fontFamily: fonts.display, fontSize: 30, color: colors.muted },
  paso: { flex: 1, fontFamily: fonts.display, fontSize: 34, lineHeight: 36, color: colors.white, textTransform: 'uppercase' },
  botones: { flexDirection: 'row', gap: 12, paddingHorizontal: 16 },
  atras: { width: 80, minHeight: 72, borderRadius: 20, borderWidth: 2, borderColor: colors.white, alignItems: 'center', justifyContent: 'center' },
  sig: { flex: 1, minHeight: 72, borderRadius: 20, backgroundColor: colors.lime, flexDirection: 'row', gap: 8, alignItems: 'center', justifyContent: 'center' },
  sigText: { fontFamily: fonts.display, fontSize: 32, color: colors.ink, textTransform: 'uppercase' },
});

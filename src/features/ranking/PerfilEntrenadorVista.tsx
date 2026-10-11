import { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Aviso, Card, Cargando, Icon, Iniciales, Screen } from '@/components';
import { perfilEntrenador } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import type { PerfilEntrenador } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';
import { formato } from './Fila';

const PESOS = [
  { id: 'uso' as const, label: 'Uso de sus ejercicios', peso: 40 },
  { id: 'constancia' as const, label: 'Constancia', peso: 30 },
  { id: 'alumnos' as const, label: 'Progreso de alumnos', peso: 30 },
];

// Perfil público de un entrenador: puntos y desglose. Sus ejercicios son anónimos: solo cuenta cuántos entrenadores los usan.
export function PerfilEntrenadorVista({ id }: { id: string }) {
  const [p, setP] = useState<PerfilEntrenador | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    perfilEntrenador(id).then(setP).catch((e) => setError(mensajeError(e)));
  }, [id]);

  return (
    <Screen back>
      <Aviso texto={error} />
      {!p && !error && <Cargando />}
      {p && (
        <>
          <View style={styles.cabecera}>
            <Iniciales nombre={p.nombre} color={colors.ink} />
            <View style={{ flex: 1 }}>
              <Text style={t.h2} accessibilityRole="header">{p.nombre}{p.es_mio ? ' (tú)' : ''}</Text>
              <Text style={styles.mut}>{p.escuelas.join(' · ')}</Text>
            </View>
          </View>

          <View style={styles.oscura}>
            <View style={styles.puntosFila}>
              <Text style={styles.etiqueta}>PUNTOS</Text>
              <Text style={styles.puntos}>{formato(p.puntos)}</Text>
            </View>
            {PESOS.map((x) => (
              <View key={x.id} style={{ gap: 4 }} accessible accessibilityLabel={`${x.label}: ${Math.round(p[x.id] / 10)} de 100, pesa un ${x.peso} %`}>
                <View style={styles.pesoFila}>
                  <Text style={styles.pesoTexto}>{x.label}</Text>
                  <Text style={styles.pesoTexto}>{x.peso} %</Text>
                </View>
                <View style={styles.pista}>
                  <View style={[styles.relleno, { width: `${Math.min(100, Math.max(0, p[x.id] / 10))}%` }]} />
                </View>
              </View>
            ))}
          </View>

          <Card style={styles.fila}>
            <Icon name="lock" color={colors.blue} />
            <View style={{ flex: 1 }}>
              <Text style={styles.titulo}>Ejercicios anónimos</Text>
              <Text style={styles.mut}>En la biblioteca no aparece quién los sube. Aquí solo cuenta cuántos entrenadores los usan.</Text>
            </View>
          </Card>

          <Card style={styles.fila}>
            <Text style={styles.grande}>{p.usos}</Text>
            <Text style={[styles.titulo, { flex: 1 }]}>usos de sus ejercicios por otros entrenadores</Text>
          </Card>
        </>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  cabecera: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  oscura: { backgroundColor: colors.ink, borderRadius: 20, padding: 18, gap: 14 },
  puntosFila: { flexDirection: 'row', alignItems: 'baseline', justifyContent: 'space-between' },
  etiqueta: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, color: colors.muted },
  puntos: { fontFamily: fonts.display, fontSize: 52, color: colors.lime },
  pesoFila: { flexDirection: 'row', justifyContent: 'space-between' },
  pesoTexto: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.white },
  pista: { height: 8, borderRadius: 4, backgroundColor: 'rgba(255,255,255,0.18)', overflow: 'hidden' },
  relleno: { height: 8, borderRadius: 4, backgroundColor: colors.blue },
  fila: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  titulo: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  grande: { fontFamily: fonts.display, fontSize: 48, color: colors.ink },
});

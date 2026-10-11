import { useCallback, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Aviso, Card, Cargando, Screen, Tag } from '@/components';
import { Medidor } from '@/features/fundador/Graficos';
import { escuelasFundador } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { etiquetaSesion } from '@/lib/fechas';
import type { EscuelaPiloto } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

// El piloto: una tarjeta por escuela con lo que hace falta para ver si está funcionando
export default function Piloto() {
  const [escuelas, setEscuelas] = useState<EscuelaPiloto[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);

  const cargar = useCallback(async () => {
    try {
      setEscuelas(await escuelasFundador());
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, []);
  useFocusEffect(
    useCallback(() => {
      cargar();
    }, [cargar]),
  );

  return (
    <Screen
      title="Piloto"
      subtitle={escuelas ? `${escuelas.length} ${escuelas.length === 1 ? 'escuela' : 'escuelas'}` : undefined}
      refreshing={refrescando}
      onRefresh={async () => {
        setRefrescando(true);
        await cargar();
        setRefrescando(false);
      }}
    >
      <Aviso texto={error} />
      {!escuelas && !error && <Cargando />}
      {escuelas?.length === 0 && (
        <Card>
          <Text style={t.h3}>Aún no hay escuelas</Text>
        </Card>
      )}
      {escuelas?.map((e) => (
        <Card key={e.id}>
          <View style={styles.cabecera}>
            <View style={{ flex: 1 }}>
              <Text style={styles.nombre}>{e.nombre}</Text>
              <Text style={styles.mut}>{[...new Set([e.ciudad, e.provincia].filter(Boolean))].join(' · ')}</Text>
            </View>
            {e.participa ? <Tag texto="En el ranking" tipo="lima" /> : <Tag texto="Fuera del ranking" tipo="naranja" />}
          </View>

          <View style={styles.cifras}>
            <Dato valor={e.entrenadores} etiqueta="Entrenadores" />
            <Dato valor={e.alumnos} etiqueta="Alumnos" />
            <Dato valor={e.grupos} etiqueta="Grupos" />
            <Dato valor={e.ejercicios} etiqueta="Ejercicios" />
          </View>

          <Medidor
            etiqueta="Familias vinculadas"
            parte={e.alumnos_con_familia}
            total={e.alumnos}
            detalle={`${e.alumnos_con_familia} de ${e.alumnos} alumnos (los demás no suman XP)`}
          />
          <Medidor
            etiqueta="Asistencias confirmadas (4 semanas)"
            parte={e.confirmadas_4_semanas}
            total={e.asistencias_4_semanas}
            detalle={`${e.clases_4_semanas} clases con lista · ${e.confirmadas_4_semanas} de ${e.asistencias_4_semanas} asistencias`}
          />
          <Text style={styles.mut}>
            {e.ultima_clase ? `Última clase con lista: ${etiquetaSesion(e.ultima_clase).toLowerCase()}` : 'Aún no ha pasado lista'}
            {e.solicitudes_pendientes > 0 ? ` · ${e.solicitudes_pendientes} ${e.solicitudes_pendientes === 1 ? 'solicitud pendiente' : 'solicitudes pendientes'}` : ''}
          </Text>
        </Card>
      ))}
    </Screen>
  );
}

function Dato({ valor, etiqueta }: { valor: number; etiqueta: string }) {
  return (
    <View style={{ width: '50%' }} accessible accessibilityLabel={`${etiqueta}: ${valor}`}>
      <Text style={styles.dato}>{valor}</Text>
      <Text style={styles.mut}>{etiqueta}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  cabecera: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  nombre: { fontFamily: fonts.display, fontSize: 24, color: colors.ink, textTransform: 'uppercase' },
  mut: { fontFamily: fonts.body, fontSize: 13, color: colors.ink2 },
  cifras: { flexDirection: 'row', flexWrap: 'wrap', rowGap: 8 },
  dato: { fontFamily: fonts.display, fontSize: 32, color: colors.ink },
});

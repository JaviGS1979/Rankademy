import { useCallback, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Aviso, Card, Cargando, Icon, Screen, Tag } from '@/components';
import { alertasFundador } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import type { AlertaFundador } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

const NIVELES = {
  alta: { texto: 'Atender', tipo: 'naranja' as const },
  media: { texto: 'Revisar', tipo: 'azul' as const },
  info: { texto: 'Aviso', tipo: 'tinta' as const },
};

const TITULOS: Record<string, string> = {
  sin_actividad: 'Sin actividad',
  sin_grupos: 'Sin grupos',
  solicitudes_viejas: 'Solicitudes sin atender',
  familias_sin_vincular: 'Familias sin vincular',
  sin_provincia: 'Sin provincia',
  patron_raro: 'Patrón raro',
  codigos_fallidos: 'Intentos fallidos con códigos',
};

// Alertas del fundador: lo que conviene mirar hoy (el texto lo escribe la base de datos)
export default function Alertas() {
  const [alertas, setAlertas] = useState<AlertaFundador[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);

  const cargar = useCallback(async () => {
    try {
      setAlertas(await alertasFundador());
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

  const urgentes = alertas?.filter((a) => a.nivel === 'alta').length ?? 0;
  return (
    <Screen
      title="Alertas"
      subtitle={alertas ? (alertas.length === 0 ? undefined : `${alertas.length} en total · ${urgentes} para atender`) : undefined}
      refreshing={refrescando}
      onRefresh={async () => {
        setRefrescando(true);
        await cargar();
        setRefrescando(false);
      }}
    >
      <Aviso texto={error} />
      {!alertas && !error && <Cargando />}
      {alertas?.length === 0 && (
        <Card>
          <View style={styles.vacio}>
            <Icon name="check" color={colors.blue} size={32} strokeWidth={3} />
            <Text style={t.h3}>Todo en orden</Text>
          </View>
          <Text style={styles.mut}>Ahora mismo no hay nada que atender ni revisar.</Text>
        </Card>
      )}
      {alertas?.map((a, i) => (
        <Card key={i}>
          <View style={styles.fila}>
            <Tag texto={NIVELES[a.nivel].texto} tipo={NIVELES[a.nivel].tipo} />
            <Text style={styles.titulo}>{TITULOS[a.tipo] ?? a.tipo}</Text>
          </View>
          {!!a.escuela && <Text style={styles.escuela}>{a.escuela}</Text>}
          <Text style={styles.mut}>{a.detalle}</Text>
        </Card>
      ))}
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  vacio: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  titulo: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink, flex: 1 },
  escuela: { fontFamily: fonts.display, fontSize: 22, color: colors.ink, textTransform: 'uppercase' },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

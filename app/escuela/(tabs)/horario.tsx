import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Aviso, Button, Card, Cargando, Icon, Screen, Tag } from '@/components';
import { SelectorEscuela } from '@/features/escuela/SelectorEscuela';
import { gruposDeEscuela } from '@/lib/api';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import { horaCorta, nombreDia } from '@/lib/fechas';
import { useSesion } from '@/lib/sesion';
import type { GrupoEscuela } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

export default function Horario() {
  const router = useRouter();
  const { session } = useSesion();
  const { actual, esDirector } = useEscuela();
  const [grupos, setGrupos] = useState<GrupoEscuela[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);
  const escuelaId = actual?.id;

  const cargar = useCallback(async () => {
    if (!escuelaId) return;
    try {
      setGrupos(await gruposDeEscuela(escuelaId));
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [escuelaId]);

  useFocusEffect(
    useCallback(() => {
      setGrupos(null);
      cargar();
    }, [cargar]),
  );

  const refrescar = async () => {
    setRefrescando(true);
    await cargar();
    setRefrescando(false);
  };

  return (
    <Screen
      title="Horario"
      subtitle={`${actual?.nombre ?? ''} · cada grupo es un día y una hora.`}
      refreshing={refrescando}
      onRefresh={refrescar}
    >
      <SelectorEscuela />
      <Aviso texto={error} />
      {!grupos && !error && <Cargando />}

      {grupos?.length === 0 && (
        <Card>
          <Text style={t.h3}>Aún no hay grupos</Text>
          <Text style={styles.mut}>
            {esDirector ? 'Crea el primero: un día, una hora y, si quieres, su entrenador.' : 'Los grupos los crea el director.'}
          </Text>
        </Card>
      )}

      {grupos?.map((g) => (
        <Pressable
          key={g.id}
          accessibilityRole="button"
          accessibilityLabel={`${g.nombre}, ${nombreDia(g.dia)} ${horaCorta(g.hora)}`}
          onPress={() => router.push({ pathname: '/escuela/grupo', params: { id: g.id } })}
          style={({ pressed }) => [styles.card, pressed && { opacity: 0.85 }]}
        >
          <View style={{ flex: 1, gap: 6 }}>
            <Text style={styles.nombre}>{g.nombre}</Text>
            <Text style={styles.mut}>
              {nombreDia(g.dia)} · {horaCorta(g.hora)}
              {g.pista ? ` · Pista ${g.pista}` : ''}
            </Text>
            <View style={styles.tags}>
              {g.entrenador_id === session?.user.id && <Tag texto="Tuyo" tipo="lima" />}
              {!g.entrenador_id && <Tag texto="Sin entrenador" tipo="naranja" />}
              {g.entrenador_id && g.entrenador_id !== session?.user.id && (
                <Tag texto={g.entrenador?.nombre || 'Entrenador'} tipo="azul" />
              )}
              <Tag texto={g.alumnos === 1 ? '1 alumno' : `${g.alumnos} alumnos`} tipo="tinta" />
            </View>
          </View>
          <Icon name="next" />
        </Pressable>
      ))}

      {esDirector && <Button label="Crear grupo" variant="lime" onPress={() => router.push('/escuela/crear-grupo')} />}
    </Screen>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row', alignItems: 'center', gap: 12, padding: 16, borderRadius: 20, borderWidth: 1,
    borderColor: colors.line, backgroundColor: colors.card, minHeight: 88,
  },
  nombre: { fontFamily: fonts.display, fontSize: 22, color: colors.ink, textTransform: 'uppercase' },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  tags: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
});

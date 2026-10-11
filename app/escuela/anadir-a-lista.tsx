import { useCallback, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Cargando, Field, Iniciales, Screen, Tag } from '@/components';
import { alumnosDeEscuela, listaDeClase, marcarAsistencia } from '@/lib/api';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import type { AlumnoEscuela } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

// Añadir a la clase a un alumno de la escuela que no está en el grupo (recupera una clase, viene de visita…)
export default function AnadirALista() {
  const router = useRouter();
  const { sesion } = useLocalSearchParams<{ sesion: string }>();
  const { actual } = useEscuela();
  const [alumnos, setAlumnos] = useState<AlumnoEscuela[] | null>(null);
  const [enLista, setEnLista] = useState<Set<string>>(new Set());
  const [anadidos, setAnadidos] = useState<Set<string>>(new Set());
  const [busqueda, setBusqueda] = useState('');
  const [error, setError] = useState<string | null>(null);
  const escuelaId = actual?.id;

  const cargar = useCallback(async () => {
    if (!escuelaId || !sesion) return;
    try {
      const [als, lista] = await Promise.all([alumnosDeEscuela(escuelaId), listaDeClase(sesion)]);
      setAlumnos(als);
      setEnLista(new Set(lista.map((f) => f.perfil_id)));
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [escuelaId, sesion]);

  useFocusEffect(
    useCallback(() => {
      cargar();
    }, [cargar]),
  );

  const anadir = async (a: AlumnoEscuela) => {
    setError(null);
    try {
      await marcarAsistencia(sesion, a.perfil_id, 'presente');
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      setAnadidos((s) => new Set(s).add(a.perfil_id));
    } catch (e) {
      setError(mensajeError(e));
    }
  };

  const q = busqueda.trim().toLowerCase();
  const visibles = (alumnos ?? []).filter(
    (a) => !enLista.has(a.perfil_id) && (!q || `${a.nombre} ${a.apellidos}`.toLowerCase().includes(q)),
  );

  return (
    <Screen back title={'Añadir a\nla clase'} subtitle="Todos los alumnos de tu escuela.">
      <Field label="Buscar alumno" placeholder="Nombre" value={busqueda} onChangeText={setBusqueda} autoCorrect={false} />
      <Aviso texto={error} />
      {!alumnos && !error && <Cargando />}
      {alumnos && visibles.length === 0 && (
        <Text style={styles.mut}>{q ? 'Ningún alumno con ese nombre.' : 'Todos los alumnos de la escuela ya están en la lista.'}</Text>
      )}
      {visibles.map((a) => {
        const hecho = anadidos.has(a.perfil_id);
        const nombre = `${a.nombre} ${a.apellidos}`.trim();
        return (
          <View key={a.perfil_id} style={styles.fila}>
            <Iniciales nombre={nombre} color={colors.blue} />
            <View style={{ flex: 1, gap: 2 }}>
              <Text style={styles.nombre}>{nombre}</Text>
              <Text style={styles.mut}>{a.grupos.length ? a.grupos.map((g) => g.nombre).join(' · ') : 'Sin horario fijo'}</Text>
            </View>
            {hecho ? <Tag texto="Añadido" tipo="lima" /> : <Button label="Añadir" variant="lime" small onPress={() => anadir(a)} />}
          </View>
        );
      })}
      <Button label="Listo" variant="dark" onPress={() => router.back()} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: {
    flexDirection: 'row', alignItems: 'center', gap: 12, padding: 12, borderRadius: 16, borderWidth: 1,
    borderColor: colors.line, backgroundColor: colors.card, minHeight: 64,
  },
  nombre: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

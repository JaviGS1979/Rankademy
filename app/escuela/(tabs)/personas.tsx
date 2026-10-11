import { useCallback, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Redirect, useFocusEffect, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, Chip, CodigoCaja, Iniciales, Screen, Tag } from '@/components';
import { SelectorEscuela } from '@/features/escuela/SelectorEscuela';
import { SolicitudFila } from '@/features/escuela/SolicitudFila';
import {
  alumnosDeEscuela, codigoAlumno, darDeBaja, entrenadoresDeEscuela, resolverSolicitud, solicitudesPendientes,
} from '@/lib/api';
import { confirmar } from '@/lib/avisar';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import type { AlumnoEscuela, EntrenadorEscuela, Solicitud } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

type Vista = 'entrenadores' | 'alumnos';

// Personas de la escuela (solo director): solicitudes, entrenadores y alumnos
export default function Personas() {
  const router = useRouter();
  const { actual, esDirector } = useEscuela();
  const [vista, setVista] = useState<Vista>('alumnos');
  const [entrenadores, setEntrenadores] = useState<EntrenadorEscuela[] | null>(null);
  const [alumnos, setAlumnos] = useState<AlumnoEscuela[] | null>(null);
  const [solicitudes, setSolicitudes] = useState<Solicitud[]>([]);
  const [codigos, setCodigos] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);
  const escuelaId = actual?.id;

  const cargar = useCallback(async () => {
    if (!escuelaId) return;
    try {
      const [e, a, s] = await Promise.all([
        entrenadoresDeEscuela(escuelaId),
        alumnosDeEscuela(escuelaId),
        solicitudesPendientes(escuelaId),
      ]);
      setEntrenadores(e);
      setAlumnos(a);
      setSolicitudes(s);
      setError(null);
    } catch (err) {
      setError(mensajeError(err));
    }
  }, [escuelaId]);

  useFocusEffect(
    useCallback(() => {
      setEntrenadores(null);
      setAlumnos(null);
      setCodigos({});
      cargar();
    }, [cargar]),
  );

  if (!esDirector) return <Redirect href="/escuela" />;

  const refrescar = async () => {
    setRefrescando(true);
    await cargar();
    setRefrescando(false);
  };

  const accion = async (f: () => Promise<void>) => {
    setError(null);
    try {
      await f();
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      await cargar();
    } catch (e) {
      setError(mensajeError(e));
    }
  };

  const baja = (membresiaId: string, nombre: string) =>
    confirmar(
      'Dar de baja',
      `${nombre} dejará de aparecer en la escuela y en sus grupos. Su historial de clases se conserva.`,
      'Dar de baja',
      () => accion(() => darDeBaja(membresiaId)),
    );

  const verCodigo = async (a: AlumnoEscuela, nuevo: boolean) => {
    setError(null);
    try {
      const c = await codigoAlumno(a.perfil_id, nuevo);
      setCodigos((cs) => ({ ...cs, [a.perfil_id]: c }));
    } catch (e) {
      setError(mensajeError(e));
    }
  };

  const lista = vista === 'entrenadores' ? entrenadores : alumnos;

  return (
    <Screen title="Personas" subtitle={actual?.nombre} refreshing={refrescando} onRefresh={refrescar}>
      <SelectorEscuela />
      <Aviso texto={error} />

      {solicitudes.length > 0 && (
        <View style={{ gap: 10 }}>
          <Text style={t.label} accessibilityRole="header">Solicitudes · {solicitudes.length}</Text>
          {solicitudes.map((s) => (
            <SolicitudFila key={s.id} s={s} onResolver={(sol, aprobar) => accion(() => resolverSolicitud(sol.id, aprobar))} />
          ))}
        </View>
      )}

      <View style={styles.fila} accessibilityRole="radiogroup">
        <Chip texto={`Entrenadores · ${entrenadores?.length ?? '–'}`} on={vista === 'entrenadores'} onPress={() => setVista('entrenadores')} />
        <Chip texto={`Alumnos · ${alumnos?.length ?? '–'}`} on={vista === 'alumnos'} onPress={() => setVista('alumnos')} />
      </View>

      {!lista && !error && <Cargando />}
      {lista?.length === 0 && (
        <Card>
          <Text style={t.h3}>{vista === 'alumnos' ? 'Aún no hay alumnos' : 'Aún no hay entrenadores'}</Text>
          <Text style={styles.mut}>
            {vista === 'alumnos'
              ? 'Inscribe a tus alumnos tú mismo, o comparte el código de la escuela con las familias.'
              : 'Los entrenadores se unen con el código de la escuela y tú los apruebas aquí.'}
          </Text>
        </Card>
      )}

      {vista === 'entrenadores' &&
        entrenadores?.map((e) => (
          <View key={e.membresia_id} style={styles.persona}>
            <Iniciales nombre={e.nombre} color={colors.orange} />
            <View style={{ flex: 1, gap: 2 }}>
              <Text style={styles.nombre}>{e.nombre}</Text>
              <Text style={styles.mut}>{e.grupos.length ? e.grupos.join(' · ') : 'Sin grupo asignado'}</Text>
            </View>
            <Button label="Baja" variant="ghost" small onPress={() => baja(e.membresia_id, e.nombre)} />
          </View>
        ))}

      {vista === 'alumnos' &&
        alumnos?.map((a) => {
          const nombre = `${a.nombre} ${a.apellidos}`.trim();
          return (
            <View key={a.perfil_id} style={{ gap: 8 }}>
              <View style={styles.persona}>
                <Iniciales nombre={nombre} color={colors.blue} />
                <View style={{ flex: 1, gap: 4 }}>
                  <Text style={styles.nombre}>{nombre}</Text>
                  <Text style={styles.mut}>{a.grupos.length ? a.grupos.map((g) => g.nombre).join(' · ') : 'Sin grupo'}</Text>
                  {a.sin_familia && <Tag texto="Familia sin vincular" tipo="naranja" />}
                </View>
                <Button label="Baja" variant="ghost" small onPress={() => baja(a.membresia_id, nombre)} />
              </View>
              {a.sin_familia && !codigos[a.perfil_id] && (
                <Button label="Ver código para la familia" variant="dark" small onPress={() => verCodigo(a, false)} />
              )}
              {codigos[a.perfil_id] && (
                <>
                  <CodigoCaja
                    etiqueta={`Código de ${a.nombre}`}
                    codigo={codigos[a.perfil_id]}
                    mensaje={`Vincula a ${a.nombre} en Rankademy: entra en la app, pulsa "Tengo un código de alumno" y escribe ${codigos[a.perfil_id]}`}
                    tituloAviso="Código del alumno"
                  />
                  <Button label="Generar un código nuevo" variant="ghost" small onPress={() => verCodigo(a, true)} />
                </>
              )}
            </View>
          );
        })}

      <Button label="Inscribir alumno" variant="lime" onPress={() => router.push('/escuela/alta-alumno')} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  persona: {
    flexDirection: 'row', alignItems: 'center', gap: 12, padding: 12, borderRadius: 16, borderWidth: 1,
    borderColor: colors.line, backgroundColor: colors.card, minHeight: 68,
  },
  nombre: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

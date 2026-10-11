import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, Chip, Field, Icon, Iniciales, Screen, Tag } from '@/components';
import {
  actualizarGrupo, alumnosDeEscuela, desinscribir, entrenadoresDeEscuela, gruposDeEscuela, inscribir,
} from '@/lib/api';
import { confirmar } from '@/lib/avisar';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import { etiquetaFecha, hoyISO, horaCorta, horaValida, nombreDia, ocurrenciasDelGrupo } from '@/lib/fechas';
import type { AlumnoEscuela, EntrenadorEscuela, GrupoEscuela } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

// Un grupo: sus clases, sus alumnos y (el director) sus ajustes
export default function Grupo() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { actual, esDirector } = useEscuela();
  const [grupo, setGrupo] = useState<GrupoEscuela | null | undefined>(undefined);
  const [alumnos, setAlumnos] = useState<AlumnoEscuela[]>([]);
  const [entrenadores, setEntrenadores] = useState<EntrenadorEscuela[]>([]);
  const [nombre, setNombre] = useState('');
  const [hora, setHora] = useState('');
  const [pista, setPista] = useState('');
  const [entrenador, setEntrenador] = useState<string | null>(null);
  const [apuntando, setApuntando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);
  const escuelaId = actual?.id;

  const cargar = useCallback(async () => {
    if (!escuelaId) return;
    try {
      const [grupos, als, ents] = await Promise.all([
        gruposDeEscuela(escuelaId),
        alumnosDeEscuela(escuelaId),
        entrenadoresDeEscuela(escuelaId),
      ]);
      const g = grupos.find((x) => x.id === id) ?? null;
      setGrupo(g);
      setAlumnos(als);
      setEntrenadores(ents);
      if (g) {
        setNombre(g.nombre);
        setHora(horaCorta(g.hora));
        setPista(g.pista);
        setEntrenador(g.entrenador_id);
      }
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [escuelaId, id]);

  useFocusEffect(
    useCallback(() => {
      cargar();
    }, [cargar]),
  );

  if (grupo === undefined && !error) {
    return (
      <Screen back title="Grupo">
        <Cargando />
      </Screen>
    );
  }
  if (!grupo) {
    return (
      <Screen back title="Grupo">
        <Aviso texto={error ?? 'Este grupo ya no existe.'} />
      </Screen>
    );
  }

  const delGrupo = alumnos.filter((a) => a.grupos.some((x) => x.id === grupo.id));
  const disponibles = alumnos.filter((a) => !a.grupos.some((x) => x.id === grupo.id));
  const fechas = ocurrenciasDelGrupo(grupo.dia);
  const hoy = hoyISO();

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

  const guardar = async () => {
    const horaOk = horaValida(hora);
    if (nombre.trim().length < 2) return setError('Ponle un nombre al grupo.');
    if (!horaOk) return setError('La hora tiene este formato: 17:00.');
    setGuardando(true);
    await accion(() => actualizarGrupo(grupo.id, { nombre: nombre.trim(), hora: horaOk, pista: pista.trim(), entrenador_id: entrenador }));
    setGuardando(false);
  };

  const archivar = () =>
    confirmar(
      'Archivar grupo',
      `${grupo.nombre} dejará de aparecer en el horario. El historial de asistencias se conserva.`,
      'Archivar',
      () => accion(async () => {
        await actualizarGrupo(grupo.id, { archivado_at: hoy });
        router.back();
      }),
    );

  return (
    <Screen back title={grupo.nombre} subtitle={`${nombreDia(grupo.dia)} · ${horaCorta(grupo.hora)}${grupo.pista ? ` · Pista ${grupo.pista}` : ''}`}>
      <Aviso texto={error} />

      <Text style={t.label} accessibilityRole="header">Clases</Text>
      <View style={styles.fechas}>
        {fechas.map((f) => (
          <Pressable
            key={f}
            accessibilityRole="button"
            accessibilityLabel={`Clase del ${etiquetaFecha(f)}`}
            onPress={() => router.push({ pathname: '/escuela/clase', params: { grupo: grupo.id, fecha: f } })}
            style={[styles.fecha, f === hoy && { borderColor: colors.blue }]}
          >
            <Text style={[styles.fechaText, f === hoy && { color: colors.blue }]}>{etiquetaFecha(f)}</Text>
          </Pressable>
        ))}
      </View>

      <Text style={t.label} accessibilityRole="header">
        Alumnos · {delGrupo.length}
      </Text>
      {delGrupo.length === 0 && <Text style={styles.mut}>Todavía no hay alumnos apuntados a este grupo.</Text>}
      {delGrupo.map((a) => (
        <View key={a.perfil_id} style={styles.persona}>
          <Iniciales nombre={`${a.nombre} ${a.apellidos}`} color={colors.blue} />
          <Text style={[styles.personaNombre, { flex: 1 }]}>{`${a.nombre} ${a.apellidos}`.trim()}</Text>
          {esDirector && (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={`Quitar a ${a.nombre} del grupo`}
              onPress={() =>
                confirmar('Quitar del grupo', `¿Quitar a ${a.nombre} de ${grupo.nombre}?`, 'Quitar', () =>
                  accion(() => desinscribir(a.perfil_id, grupo.id)),
                )
              }
              style={styles.quitar}
            >
              <Icon name="close" color={colors.ink2} />
            </Pressable>
          )}
        </View>
      ))}

      {esDirector && (
        <>
          <Button
            label={apuntando ? 'Cerrar' : 'Apuntar alumnos'}
            variant="dark"
            small
            onPress={() => setApuntando((v) => !v)}
          />
          {apuntando && (
            <Card>
              {disponibles.length === 0 && <Text style={styles.mut}>Todos los alumnos de la escuela ya están en este grupo.</Text>}
              {disponibles.map((a) => (
                <View key={a.perfil_id} style={styles.persona}>
                  <Text style={[styles.personaNombre, { flex: 1 }]}>{`${a.nombre} ${a.apellidos}`.trim()}</Text>
                  <Button
                    label="Añadir"
                    variant="lime"
                    small
                    onPress={() => accion(() => inscribir(a.perfil_id, grupo.id))}
                  />
                </View>
              ))}
              <Button label="Inscribir a un alumno nuevo" variant="ghost" small onPress={() => router.push('/escuela/alta-alumno')} />
            </Card>
          )}

          <Text style={t.label} accessibilityRole="header">Ajustes del grupo</Text>
          <Card>
            <Field label="Nombre" value={nombre} onChangeText={setNombre} maxLength={60} />
            <Field
              label="Hora"
              value={hora}
              onChangeText={(v) => setHora(v.replace(/[^0-9:.hH]/g, '').slice(0, 5))}
              keyboardType="numbers-and-punctuation"
              maxLength={5}
            />
            <Field label="Pista" value={pista} onChangeText={setPista} maxLength={20} />
            <View style={{ gap: 6 }}>
              <Text style={styles.label}>Entrenador</Text>
              <View style={styles.fila} accessibilityRole="radiogroup">
                <Chip texto="Sin asignar" on={entrenador === null} onPress={() => setEntrenador(null)} />
                {entrenadores.map((e) => (
                  <Chip key={e.persona_id} texto={e.nombre} on={entrenador === e.persona_id} onPress={() => setEntrenador(e.persona_id)} />
                ))}
              </View>
            </View>
            <Text style={styles.mut}>El día no se cambia: para otro día, crea otro grupo.</Text>
            <Button label="Guardar cambios" variant="lime" onPress={guardar} cargando={guardando} />
          </Card>
          <Button label="Archivar grupo" variant="ghost" small onPress={archivar} />
        </>
      )}
      {!esDirector && grupo.entrenador && <Tag texto={`Entrenador: ${grupo.entrenador.nombre}`} tipo="azul" />}
    </Screen>
  );
}

const styles = StyleSheet.create({
  label: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  fechas: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  fecha: {
    minHeight: 44, paddingHorizontal: 16, borderRadius: 999, borderWidth: 2, borderColor: colors.line,
    backgroundColor: colors.white, justifyContent: 'center',
  },
  fechaText: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.ink },
  persona: { flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 52 },
  personaNombre: { fontFamily: fonts.bodySemi, fontSize: 16, color: colors.ink },
  quitar: { width: 44, height: 44, borderRadius: 12, borderWidth: 2, borderColor: colors.line, alignItems: 'center', justifyContent: 'center' },
});

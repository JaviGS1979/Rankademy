import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, Chip, Screen, Tag } from '@/components';
import {
  cancelarClase, cancelarDia, ejerciciosDeClase, gruposDeEscuela, reactivarClase, sesionPara, sesionesDelDia,
} from '@/lib/api';
import { Pista } from '@/features/biblioteca/Pista';
import { avisar, confirmar } from '@/lib/avisar';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import { etiquetaFecha, hoyISO, horaCorta, nombreDia, ocurrenciasDelGrupo } from '@/lib/fechas';
import type { EjercicioClase, GrupoEscuela, SesionDia } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

// Preparar clase: elegir el día, ver su estado y cancelarla o reactivarla.
// Los ejercicios se añadirán aquí cuando esté lista la biblioteca.
export default function Clase() {
  const router = useRouter();
  const params = useLocalSearchParams<{ grupo: string; fecha: string }>();
  const { actual, esDirector } = useEscuela();
  const [fecha, setFecha] = useState(params.fecha ?? hoyISO());
  const [grupo, setGrupo] = useState<GrupoEscuela | null | undefined>(undefined);
  const [sesion, setSesion] = useState<SesionDia | null>(null);
  const [ejercicios, setEjercicios] = useState<EjercicioClase[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [trabajando, setTrabajando] = useState(false);
  const escuelaId = actual?.id;

  const cargar = useCallback(async () => {
    if (!escuelaId) return;
    try {
      const grupos = await gruposDeEscuela(escuelaId);
      const g = grupos.find((x) => x.id === params.grupo) ?? null;
      setGrupo(g);
      const ses = g ? ((await sesionesDelDia([g.id], fecha))[0] ?? null) : null;
      setSesion(ses);
      setEjercicios(ses ? await ejerciciosDeClase(ses.id) : []);
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [escuelaId, params.grupo, fecha]);

  useFocusEffect(
    useCallback(() => {
      cargar();
    }, [cargar]),
  );

  if (grupo === undefined && !error) {
    return (
      <Screen back title="Preparar clase">
        <Cargando />
      </Screen>
    );
  }
  if (!grupo) {
    return (
      <Screen back title="Preparar clase">
        <Aviso texto={error ?? 'Este grupo ya no existe.'} />
      </Screen>
    );
  }

  const hoy = hoyISO();
  const cancelada = sesion?.estado === 'cancelada';
  const futura = fecha > hoy;

  const accion = async (f: () => Promise<void>) => {
    setError(null);
    setTrabajando(true);
    try {
      await f();
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      await cargar();
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setTrabajando(false);
    }
  };

  return (
    <Screen back title="Preparar clase" subtitle={`${grupo.nombre} · ${nombreDia(grupo.dia)} ${horaCorta(grupo.hora)}`}>
      <Text style={t.label} accessibilityRole="header">Día</Text>
      <View style={styles.fila} accessibilityRole="radiogroup">
        {ocurrenciasDelGrupo(grupo.dia).map((f) => (
          <Chip key={f} texto={etiquetaFecha(f)} on={f === fecha} onPress={() => setFecha(f)} />
        ))}
      </View>

      <Card>
        <View style={styles.estado}>
          <Text style={t.h3}>{etiquetaFecha(fecha)}</Text>
          {cancelada ? (
            <Tag texto="Cancelada" tipo="naranja" />
          ) : sesion?.estado === 'impartida' ? (
            <Tag texto="Lista cerrada" tipo="lima" />
          ) : (
            <Tag texto={futura ? 'Programada' : 'Pendiente de lista'} tipo="azul" />
          )}
        </View>
        <Aviso texto={error} />
        {!cancelada && (
          <Button
            label="Pasar lista"
            variant="lime"
            disabled={futura}
            onPress={() => router.push({ pathname: '/escuela/lista', params: { grupo: grupo.id, fecha } })}
          />
        )}
        {futura && !cancelada && <Text style={styles.mut}>La lista se abre el día de la clase.</Text>}
        {cancelada ? (
          sesion && (
            <Button label="Reactivar clase" variant="dark" cargando={trabajando} onPress={() => accion(() => reactivarClase(sesion.id))} />
          )
        ) : (
          <Button
            label="Cancelar clase"
            variant="ghost"
            small
            cargando={trabajando}
            onPress={() =>
              confirmar('Cancelar clase', `¿Cancelar ${grupo.nombre} del ${etiquetaFecha(fecha).toLowerCase()}? No cuenta como falta para nadie.`, 'Cancelar clase', () =>
                accion(() => cancelarClase(grupo.id, fecha)),
              )
            }
          />
        )}
        {esDirector && (
          <Button
            label="Cancelar todas las clases de este día"
            variant="ghost"
            small
            cargando={trabajando}
            onPress={() =>
              confirmar(
                'Cancelar el día',
                'Se cancelan todas las clases de la escuela de ese día (por ejemplo, un festivo). Las que ya tengan asistencias confirmadas por las familias se quedan como están.',
                'Cancelar el día',
                () =>
                  accion(async () => {
                    const n = await cancelarDia(actual!.id, fecha);
                    avisar('Día cancelado', n === 1 ? 'Se canceló 1 clase.' : `Se cancelaron ${n} clases.`);
                  }),
              )
            }
          />
        )}
      </Card>

      <Card>
        <Text style={t.h3}>Ejercicios de la clase</Text>
        {ejercicios.length === 0 && <Text style={styles.mut}>Aún no hay ejercicios elegidos para esta clase.</Text>}
        {ejercicios.map((e, i) => (
          <Pressable
            key={e.id}
            accessibilityRole="button"
            accessibilityLabel={`${i + 1}. ${e.titulo}`}
            onPress={() => router.push({ pathname: '/escuela/ejercicio', params: { id: e.id } })}
            style={styles.ejercicio}
          >
            <View style={styles.miniPista}>
              <Pista elementos={e.dibujo ?? []} miniatura style={{ borderRadius: 8 }} />
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.ejTitulo}>{e.titulo}</Text>
              <Text style={styles.mut}>{e.jugadores_min}-{e.jugadores_max} jugadores{e.retirado ? ' · retirado' : ''}</Text>
            </View>
            <Text style={styles.ejNum}>{i + 1}</Text>
          </Pressable>
        ))}
        {!cancelada && (
          <Button
            label={ejercicios.length ? 'Cambiar ejercicios' : 'Añadir de la biblioteca'}
            variant="dark"
            small
            cargando={trabajando}
            onPress={() =>
              accion(async () => {
                const id = sesion?.id ?? (await sesionPara(grupo.id, fecha));
                router.push({ pathname: '/escuela/elegir-ejercicios', params: { sesion: id } });
              })
            }
          />
        )}
        <Text style={styles.mut}>Los alumnos del grupo verán estos ejercicios en su perfil.</Text>
      </Card>
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  estado: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  ejercicio: { flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 60 },
  miniPista: { width: 84 },
  ejTitulo: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  ejNum: { fontFamily: fonts.display, fontSize: 28, color: colors.ink2 },
});

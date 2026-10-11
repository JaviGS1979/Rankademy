import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { Image } from 'expo-image';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, Icon, Screen, Tag } from '@/components';
import {
  cerrarLista, gruposDeEscuela, listaDeClase, marcarAsistencia, reactivarClase, sesionPara, sesionesDelDia,
} from '@/lib/api';
import { miniaturas } from '@/lib/avatares';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import { etiquetaFecha, hoyISO, horaCorta, nombreDia } from '@/lib/fechas';
import type { EstadoAsistencia, FilaLista, GrupoEscuela } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

type Marca = 'presente' | 'justificada';

// Pasar lista: el entrenador marca quién ha venido. Cada familia lo confirma después
// en su perfil, y solo entonces el alumno recibe sus XP.
export default function Lista() {
  const router = useRouter();
  const { grupo: grupoId, fecha } = useLocalSearchParams<{ grupo: string; fecha: string }>();
  const { actual } = useEscuela();
  const [grupo, setGrupo] = useState<GrupoEscuela | null>(null);
  const [sesionId, setSesionId] = useState<string | null>(null);
  const [cancelada, setCancelada] = useState(false);
  const [filas, setFilas] = useState<FilaLista[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [cerrando, setCerrando] = useState(false);
  const escuelaId = actual?.id;
  const futura = !!fecha && fecha > hoyISO();

  const cargar = useCallback(async () => {
    if (!escuelaId || !grupoId || !fecha) return;
    try {
      const g = (await gruposDeEscuela(escuelaId)).find((x) => x.id === grupoId) ?? null;
      setGrupo(g);
      if (!g) return setFilas([]);
      if (fecha > hoyISO()) {
        // Una clase futura no se abre todavía: no se crea la sesión
        setFilas([]);
        return;
      }
      const id = await sesionPara(grupoId, fecha);
      setSesionId(id);
      const [lista, ses] = await Promise.all([listaDeClase(id), sesionesDelDia([grupoId], fecha)]);
      setCancelada(ses[0]?.estado === 'cancelada');
      setFilas(lista);
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
      setFilas((f) => f ?? []);
    }
  }, [escuelaId, grupoId, fecha]);

  useFocusEffect(
    useCallback(() => {
      cargar();
    }, [cargar]),
  );

  const marcar = async (fila: FilaLista, marca: Marca) => {
    if (!sesionId || fila.estado === 'confirmada') return;
    // Pulsar la marca que ya tiene la quita
    const nuevo: Marca | 'ninguno' = fila.estado === marca ? 'ninguno' : marca;
    const anterior = filas;
    setFilas((fs) => fs?.map((f) => (f.perfil_id === fila.perfil_id ? { ...f, estado: nuevo === 'ninguno' ? null : nuevo } : f)) ?? null);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
    setError(null);
    try {
      await marcarAsistencia(sesionId, fila.perfil_id, nuevo);
    } catch (e) {
      setFilas(anterior);
      setError(mensajeError(e));
    }
  };

  const confirmarLista = async () => {
    if (!sesionId) return;
    setCerrando(true);
    try {
      await cerrarLista(sesionId);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      router.back();
    } catch (e) {
      setError(mensajeError(e));
      setCerrando(false);
    }
  };

  const titulo = grupo ? `${grupo.nombre} · ${nombreDia(grupo.dia)} ${horaCorta(grupo.hora)}` : 'Pasar lista';
  const asistentes = (filas ?? []).filter((f) => f.estado === 'presente' || f.estado === 'confirmada').length;

  return (
    <Screen back title="Pasar lista" subtitle={`${titulo}${fecha ? ` · ${etiquetaFecha(fecha)}` : ''}`}>
      <Aviso texto={error} />
      {!filas && !error && <Cargando />}

      {futura && (
        <Card>
          <Text style={t.h3}>Todavía no es el día</Text>
          <Text style={styles.mut}>La lista se abre el día de la clase.</Text>
        </Card>
      )}

      {cancelada && (
        <Card>
          <Text style={t.h3}>Clase cancelada</Text>
          <Text style={styles.mut}>No se pasa lista en una clase cancelada.</Text>
          {sesionId && (
            <Button
              label="Reactivar clase"
              variant="dark"
              small
              onPress={async () => {
                try {
                  await reactivarClase(sesionId);
                  await cargar();
                } catch (e) {
                  setError(mensajeError(e));
                }
              }}
            />
          )}
        </Card>
      )}

      {!futura && !cancelada && filas && (
        <>
          <View style={styles.contador} accessibilityLabel={`${asistentes} presentes de ${filas.length}`}>
            <Text style={styles.contadorNum}>{asistentes}</Text>
            <Text style={styles.contadorDe}>/ {filas.length}</Text>
          </View>
          <Text style={styles.mut}>Marca ✓ si ha venido y J si faltó con justificación (no rompe su racha).</Text>
          {filas.length === 0 && (
            <Text style={styles.mut}>
              Este grupo aún no tiene alumnos. Apúntalos desde Horario, o añade alumnos a esta clase con el botón de abajo.
            </Text>
          )}
          {filas.map((f) => (
            <FilaAlumno key={f.perfil_id} fila={f} onMarcar={marcar} />
          ))}
          <Button
            label="Añadir alumno"
            variant="ghost"
            small
            onPress={() => router.push({ pathname: '/escuela/anadir-a-lista', params: { sesion: sesionId, grupo: grupoId, fecha } })}
          />
          <Text style={styles.mut}>Cada alumno confirma su asistencia en su perfil para recibir sus XP y logros.</Text>
          <Button label="Confirmar lista" variant="lime" onPress={confirmarLista} cargando={cerrando} />
        </>
      )}
    </Screen>
  );
}

const etiquetaEstado: Record<Exclude<EstadoAsistencia, null>, string> = {
  presente: 'Presente',
  justificada: 'Falta justificada',
  confirmada: 'Confirmada por la familia',
};

function FilaAlumno({ fila, onMarcar }: { fila: FilaLista; onMarcar: (f: FilaLista, m: Marca) => void }) {
  const bloqueada = fila.estado === 'confirmada';
  const presente = fila.estado === 'presente' || fila.estado === 'confirmada';
  const nombre = `${fila.nombre} ${fila.apellidos}`.trim();
  return (
    <View style={[styles.fila, presente && { borderColor: colors.lime, backgroundColor: '#F7FBD9' }]}>
      <Image source={miniaturas[fila.avatar ?? 'av01']} style={styles.av} contentFit="cover" accessibilityElementsHidden />
      <View style={{ flex: 1, gap: 4 }}>
        <Text style={styles.nombre}>{nombre}</Text>
        <View style={styles.tags}>
          {fila.estado && <Tag texto={etiquetaEstado[fila.estado]} tipo={fila.estado === 'justificada' ? 'azul' : 'lima'} />}
          {!fila.inscrito && <Tag texto="Añadido a esta clase" tipo="tinta" />}
        </View>
      </View>
      {bloqueada ? (
        <View style={[styles.boton, { backgroundColor: colors.lime, borderColor: colors.lime }]} accessibilityLabel="Confirmada">
          <Icon name="check" color={colors.ink} strokeWidth={3} />
        </View>
      ) : (
        <View style={styles.botones}>
          <Pressable
            accessibilityRole="checkbox"
            accessibilityState={{ checked: fila.estado === 'presente' }}
            accessibilityLabel={`${nombre}: presente`}
            onPress={() => onMarcar(fila, 'presente')}
            style={[styles.boton, fila.estado === 'presente' && { backgroundColor: colors.lime, borderColor: colors.lime }]}
          >
            <Icon name="check" color={colors.ink} strokeWidth={3} />
          </Pressable>
          <Pressable
            accessibilityRole="checkbox"
            accessibilityState={{ checked: fila.estado === 'justificada' }}
            accessibilityLabel={`${nombre}: falta justificada`}
            onPress={() => onMarcar(fila, 'justificada')}
            style={[styles.boton, fila.estado === 'justificada' && { backgroundColor: colors.blueLight, borderColor: colors.blue }]}
          >
            <Text style={styles.just}>J</Text>
          </Pressable>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  contador: { flexDirection: 'row', alignItems: 'baseline', gap: 6 },
  contadorNum: { fontFamily: fonts.display, fontSize: 56, color: colors.blue },
  contadorDe: { fontFamily: fonts.display, fontSize: 28, color: colors.ink2 },
  fila: {
    flexDirection: 'row', alignItems: 'center', gap: 12, padding: 12, borderRadius: 16, borderWidth: 2,
    borderColor: colors.line, backgroundColor: colors.card, minHeight: 72,
  },
  av: { width: 44, height: 44, borderRadius: 22 },
  nombre: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  tags: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  botones: { flexDirection: 'row', gap: 8 },
  boton: { width: 44, height: 44, borderRadius: 12, borderWidth: 2, borderColor: colors.line, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.white },
  just: { fontFamily: fonts.bodyHeavy, fontSize: 16, color: colors.ink },
});

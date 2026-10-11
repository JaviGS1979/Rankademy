import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Aviso, Button, Card, Cargando, Screen, Tag } from '@/components';
import { SelectorEscuela } from '@/features/escuela/SelectorEscuela';
import { gruposDeEscuela, miNombre, sesionesDelDia, solicitudesPendientes } from '@/lib/api';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import { diaSemana, etiquetaDia, hoyISO, horaCorta, nombreDia, proximaClase } from '@/lib/fechas';
import { useSesion } from '@/lib/sesion';
import type { GrupoEscuela, SesionDia } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

type Datos = {
  nombre: string;
  grupos: GrupoEscuela[];
  sesiones: SesionDia[];
  pendientes: number;
};

// Hoy: las clases del día. El entrenador ve las suyas; el director, las de toda la escuela.
export default function Hoy() {
  const router = useRouter();
  const { session } = useSesion();
  const { actual, esDirector } = useEscuela();
  const [datos, setDatos] = useState<Datos | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);
  const uid = session?.user.id;
  const escuelaId = actual?.id;

  const cargar = useCallback(async () => {
    if (!escuelaId) return;
    try {
      const [nombre, grupos] = await Promise.all([miNombre(), gruposDeEscuela(escuelaId)]);
      const hoy = hoyISO();
      const deHoy = grupos.filter((g) => g.dia === diaSemana());
      const [sesiones, pendientes] = await Promise.all([
        sesionesDelDia(deHoy.map((g) => g.id), hoy),
        esDirector ? solicitudesPendientes(escuelaId).then((l) => l.length) : Promise.resolve(0),
      ]);
      setDatos({ nombre, grupos, sesiones, pendientes });
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [escuelaId, esDirector]);

  useFocusEffect(
    useCallback(() => {
      setDatos(null);
      cargar();
    }, [cargar]),
  );

  const refrescar = async () => {
    setRefrescando(true);
    await cargar();
    setRefrescando(false);
  };

  const mias = (datos?.grupos ?? []).filter((g) => esDirector || g.entrenador_id === uid);
  const deHoy = mias.filter((g) => g.dia === diaSemana());
  const proxima = proximaClase(mias);
  const nombre = datos?.nombre.split(' ')[0];

  return (
    <Screen
      title="Hoy"
      subtitle={nombre ? `Hola, ${nombre} · ${actual?.nombre ?? ''}` : actual?.nombre}
      refreshing={refrescando}
      onRefresh={refrescar}
    >
      <SelectorEscuela />
      <Aviso texto={error} />
      {!datos && !error && <Cargando />}

      {datos && datos.pendientes > 0 && (
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/escuela/personas')}
          style={styles.pendientes}
        >
          <Text style={styles.pendientesText}>
            {datos.pendientes === 1 ? '1 solicitud' : `${datos.pendientes} solicitudes`} esperando tu aprobación
          </Text>
          <Text style={styles.pendientesLink}>Ver</Text>
        </Pressable>
      )}

      {datos && (
        <Text style={t.label} accessibilityRole="header">
          Hoy · {nombreDia(diaSemana()).toLowerCase()}
        </Text>
      )}

      {datos && deHoy.length === 0 && (
        <Card>
          <Text style={t.h3}>Hoy no hay clases</Text>
          <Text style={styles.mut}>
            {proxima
              ? `La próxima es ${proxima.grupo.nombre}: ${etiquetaDia(proxima.cuando)} a las ${horaCorta(proxima.grupo.hora)}.`
              : esDirector
                ? 'Crea el primer grupo desde la pestaña Horario.'
                : 'Cuando el director te asigne un grupo, aparecerá aquí.'}
          </Text>
        </Card>
      )}

      {deHoy.map((g) => {
        const sesion = datos?.sesiones.find((s) => s.grupo_id === g.id);
        const cancelada = sesion?.estado === 'cancelada';
        const hecha = sesion?.estado === 'impartida';
        return (
          <Card key={g.id} style={cancelada ? { opacity: 0.7 } : undefined}>
            <View style={styles.fila}>
              <Text style={styles.hora}>{horaCorta(g.hora)}</Text>
              <View style={{ flex: 1, gap: 2 }}>
                <Text style={styles.nombre}>{g.nombre}</Text>
                <Text style={styles.mut}>
                  {g.pista ? `Pista ${g.pista} · ` : ''}
                  {g.alumnos === 1 ? '1 alumno' : `${g.alumnos} alumnos`}
                </Text>
              </View>
              {cancelada && <Tag texto="Cancelada" tipo="naranja" />}
              {hecha && <Tag texto="Lista cerrada" tipo="lima" />}
            </View>
            {!cancelada && (
              <Button
                label="Pasar lista"
                variant="lime"
                onPress={() => router.push({ pathname: '/escuela/lista', params: { grupo: g.id, fecha: hoyISO() } })}
              />
            )}
            <Button
              label="Preparar clase"
              variant="ghost"
              small
              onPress={() => router.push({ pathname: '/escuela/clase', params: { grupo: g.id, fecha: hoyISO() } })}
            />
          </Card>
        );
      })}

    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  hora: { fontFamily: fonts.display, fontSize: 34, color: colors.blue },
  nombre: { fontFamily: fonts.display, fontSize: 22, color: colors.ink, textTransform: 'uppercase' },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  pendientes: {
    flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 56, backgroundColor: colors.orangeLight,
    borderRadius: 16, paddingHorizontal: 16, paddingVertical: 10,
  },
  pendientesText: { flex: 1, fontFamily: fonts.bodyBold, fontSize: 15, color: colors.orangeDark },
  pendientesLink: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.orangeDark, textDecorationLine: 'underline' },
});

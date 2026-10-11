import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, CodigoCaja, Iniciales, Screen, Tag } from '@/components';
import { SolicitudFila } from '@/features/escuela/SolicitudFila';
import { cerrarSesion, misMembresias, resolverSolicitud, solicitudesPendientes } from '@/lib/api';
import { confirmar } from '@/lib/avisar';
import { mensajeError } from '@/lib/errores';
import { useEsFundador } from '@/lib/useFundador';
import type { MiMembresia, Rol, Solicitud } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

const nombreRol: Record<Rol, string> = { director: 'Director', entrenador: 'Entrenador', alumno: 'Alumno' };
const coloresAv = [colors.blue, colors.orange, colors.ink];

export default function MisEscuelas() {
  const router = useRouter();
  const fundador = useEsFundador();
  const { nueva } = useLocalSearchParams<{ nueva?: string }>();
  const [membresias, setMembresias] = useState<MiMembresia[] | null>(null);
  const [solicitudes, setSolicitudes] = useState<Record<string, Solicitud[]>>({});
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);

  const cargar = useCallback(async () => {
    try {
      const ms = await misMembresias();
      setMembresias(ms);
      const dirigidas = ms.filter((m) => m.rol === 'director' && m.estado === 'activa');
      const pares = await Promise.all(
        dirigidas.map(async (m) => [m.escuela.id, await solicitudesPendientes(m.escuela.id)] as const),
      );
      setSolicitudes(Object.fromEntries(pares));
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

  const refrescar = async () => {
    setRefrescando(true);
    await cargar();
    setRefrescando(false);
  };

  const resolver = async (s: Solicitud, aprobar: boolean) => {
    try {
      await resolverSolicitud(s.id, aprobar);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      await cargar();
    } catch (e) {
      setError(mensajeError(e));
    }
  };

  const salir = () =>
    confirmar('Cerrar sesión', '¿Seguro que quieres salir?', 'Salir', () => {
      cerrarSesion().catch((e) => setError(mensajeError(e)));
    });

  return (
    <Screen title="Mis escuelas" subtitle="Una cuenta, varias escuelas." refreshing={refrescando} onRefresh={refrescar}>
      <Aviso texto={error} />
      {membresias === null && !error && <Cargando />}

      {membresias?.length === 0 && (
        <Card>
          <Text style={t.h3}>Aún no estás en ninguna escuela</Text>
          <Text style={styles.mut}>Pide el código a tu escuela, o crea la tuya si eres director.</Text>
        </Card>
      )}

      {membresias?.map((m, i) => (
        <View key={m.id} style={{ gap: 10 }}>
          <Card style={m.escuela.id === nueva ? styles.destacada : undefined}>
            <View style={styles.fila}>
              <Iniciales nombre={m.escuela.nombre} color={coloresAv[i % coloresAv.length]} />
              <View style={{ flex: 1, gap: 2 }}>
                <Text style={styles.nombre}>{m.escuela.nombre}</Text>
                <Text style={styles.mut}>
                  {m.estado === 'pendiente' ? 'Esperando al director' : m.escuela.ciudad}
                </Text>
              </View>
            </View>
            <View style={styles.tags}>
              <Tag texto={m.perfil ? `${m.perfil.nombre} · ${nombreRol[m.rol]}` : nombreRol[m.rol]} tipo="tinta" />
              {m.estado === 'activa' ? <Tag texto="Activa" tipo="lima" /> : <Tag texto="Pendiente" tipo="naranja" />}
            </View>
            {m.rol === 'director' && m.estado === 'activa' && (
              <CodigoCaja
                etiqueta="Código para compartir"
                codigo={m.escuela.codigo}
                mensaje={`Únete a ${m.escuela.nombre} en Rankademy con el código ${m.escuela.codigo}`}
                tituloAviso="Código de tu escuela"
              />
            )}
            {(m.rol === 'director' || m.rol === 'entrenador') && m.estado === 'activa' && (
              <Button label="Abrir la escuela" variant="dark" small onPress={() => router.push('/escuela')} />
            )}
          </Card>

          {(solicitudes[m.escuela.id] ?? []).map((s) => (
            <View key={s.id} style={{ marginLeft: 16 }}>
              <SolicitudFila s={s} onResolver={resolver} />
            </View>
          ))}
        </View>
      ))}

      <Button label="Añadir otra escuela" variant="dark" onPress={() => router.push('/anadir-escuela')} />
      <Button label="Crear una escuela" variant="ghost" onPress={() => router.push('/crear-escuela')} />
      <Button label="Tengo un código de alumno" variant="ghost" onPress={() => router.push('/vincular-alumno')} />
      {fundador && <Button label="Panel del fundador" variant="blue" onPress={() => router.push('/fundador')} />}

      <Card>
        <Text style={styles.label}>Cómo cuentan tus puntos</Text>
        <Text style={styles.punto}>Cada escuela suma solo las clases que haces en ella.</Text>
        <Text style={styles.punto}>En provincia, comunidad y país apareces una sola vez, con tu total.</Text>
        <Text style={styles.punto}>Tu racha, avatares y logros te siguen a todas.</Text>
      </Card>

      <Pressable accessibilityRole="button" onPress={salir} style={styles.salir} hitSlop={8}>
        <Text style={styles.salirText}>Cerrar sesión</Text>
      </Pressable>
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  nombre: { fontFamily: fonts.display, fontSize: 22, color: colors.ink, textTransform: 'uppercase' },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  tags: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  destacada: { borderColor: colors.lime, borderWidth: 2 },
  label: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, textTransform: 'uppercase', color: colors.ink2 },
  punto: { fontFamily: fonts.body, fontSize: 15, color: colors.ink },
  salir: { minHeight: 44, alignItems: 'center', justifyContent: 'center' },
  salirText: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.orange },
});

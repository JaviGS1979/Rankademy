import { useCallback, useState } from 'react';
import { Platform, Pressable, Share, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, Icon, Iniciales, Screen, Tag } from '@/components';
import { cerrarSesion, misMembresias, resolverSolicitud, solicitudesPendientes } from '@/lib/api';
import { avisar, confirmar } from '@/lib/avisar';
import { mensajeError } from '@/lib/errores';
import type { MiMembresia, Rol, Solicitud } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

const nombreRol: Record<Rol, string> = { director: 'Director', entrenador: 'Entrenador', alumno: 'Alumno' };
const coloresAv = [colors.blue, colors.orange, colors.ink];

export default function MisEscuelas() {
  const router = useRouter();
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
              <CodigoEscuela nombre={m.escuela.nombre} codigo={m.escuela.codigo} />
            )}
          </Card>

          {(solicitudes[m.escuela.id] ?? []).map((s) => (
            <SolicitudFila key={s.id} s={s} onResolver={resolver} />
          ))}
        </View>
      ))}

      <Button label="Añadir otra escuela" variant="dark" onPress={() => router.push('/anadir-escuela')} />
      <Button label="Crear una escuela" variant="ghost" onPress={() => router.push('/crear-escuela')} />

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

function CodigoEscuela({ nombre, codigo }: { nombre: string; codigo: string }) {
  const compartir = async () => {
    const mensaje = `Únete a ${nombre} en Rankademy con el código ${codigo}`;
    if (Platform.OS === 'web' && !(navigator as Navigator & { share?: unknown }).share) {
      return avisar('Código de tu escuela', mensaje);
    }
    try {
      await Share.share({ message: mensaje });
    } catch {
      avisar('Código de tu escuela', mensaje);
    }
  };
  return (
    <View style={styles.codigoCaja}>
      <View style={{ flex: 1 }}>
        <Text style={[styles.label, { color: colors.muted }]}>Código para compartir</Text>
        <Text style={styles.codigo} accessibilityLabel={`Código ${codigo.split('').join(' ')}`} selectable>
          {codigo}
        </Text>
      </View>
      <Pressable accessibilityRole="button" accessibilityLabel="Compartir código" onPress={compartir} style={styles.compartir}>
        <Icon name="share" color={colors.ink} />
      </Pressable>
    </View>
  );
}

function SolicitudFila({ s, onResolver }: { s: Solicitud; onResolver: (s: Solicitud, aprobar: boolean) => void }) {
  const quien = s.perfil
    ? `${s.perfil.nombre} · ${new Date().getFullYear() - s.perfil.anio_nacimiento} años`
    : s.persona?.nombre || 'Sin nombre';
  const detalle = s.perfil ? `Alumno · familia de ${s.persona?.nombre || '—'}` : nombreRol[s.rol];
  return (
    <View style={styles.solicitud}>
      <View style={{ flex: 1, gap: 2 }}>
        <Text style={styles.nombreSm}>{quien}</Text>
        <Text style={styles.mut}>Pide entrar · {detalle}</Text>
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Rechazar a ${quien}`}
        onPress={() => confirmar('Rechazar solicitud', `¿Rechazar a ${quien}?`, 'Rechazar', () => onResolver(s, false))}
        style={[styles.accion, { borderColor: colors.line }]}
      >
        <Icon name="close" color={colors.ink2} />
      </Pressable>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Aprobar a ${quien}`}
        onPress={() => onResolver(s, true)}
        style={[styles.accion, { backgroundColor: colors.lime, borderColor: colors.lime }]}
      >
        <Icon name="check" color={colors.ink} strokeWidth={3} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  nombre: { fontFamily: fonts.display, fontSize: 22, color: colors.ink, textTransform: 'uppercase' },
  nombreSm: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  tags: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  destacada: { borderColor: colors.lime, borderWidth: 2 },
  label: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, textTransform: 'uppercase', color: colors.ink2 },
  punto: { fontFamily: fonts.body, fontSize: 15, color: colors.ink },
  codigoCaja: { flexDirection: 'row', alignItems: 'center', gap: 12, backgroundColor: colors.ink, borderRadius: 16, padding: 14 },
  codigo: { fontFamily: fonts.display, fontSize: 34, letterSpacing: 4, color: colors.lime },
  compartir: { width: 48, height: 48, borderRadius: 14, backgroundColor: colors.lime, alignItems: 'center', justifyContent: 'center' },
  solicitud: {
    flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: colors.card,
    borderWidth: 1, borderColor: colors.line, borderRadius: 16, padding: 12, marginLeft: 16,
  },
  accion: { width: 44, height: 44, borderRadius: 12, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
  salir: { minHeight: 44, alignItems: 'center', justifyContent: 'center' },
  salirText: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.orange },
});

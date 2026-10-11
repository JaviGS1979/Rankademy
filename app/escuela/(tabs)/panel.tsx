import { useCallback, useState } from 'react';
import { StyleSheet, Switch, Text, View } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, CodigoCaja, Iniciales, Screen, Tag } from '@/components';
import { SelectorEscuela } from '@/features/escuela/SelectorEscuela';
import { ajustarRanking, alumnosDeEscuela, entrenadoresDeEscuela, solicitudesPendientes } from '@/lib/api';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import { colors, fonts, type as t } from '@/theme';

type Cifras = { entrenadores: number; alumnos: number; solicitudes: number };

// Panel de la escuela: código, cifras y ajustes. El entrenador solo ve lo básico.
export default function Panel() {
  const router = useRouter();
  const { actual, esDirector, recargar } = useEscuela();
  const [cifras, setCifras] = useState<Cifras | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);
  const [refrescando, setRefrescando] = useState(false);
  const escuelaId = actual?.id;

  const cargar = useCallback(async () => {
    if (!escuelaId) return;
    try {
      const [e, a, s] = await Promise.all([
        entrenadoresDeEscuela(escuelaId),
        alumnosDeEscuela(escuelaId),
        esDirector ? solicitudesPendientes(escuelaId) : Promise.resolve([]),
      ]);
      setCifras({ entrenadores: e.length, alumnos: a.length, solicitudes: s.length });
      setError(null);
    } catch (err) {
      setError(mensajeError(err));
    }
  }, [escuelaId, esDirector]);

  useFocusEffect(
    useCallback(() => {
      setCifras(null);
      cargar();
    }, [cargar]),
  );

  const refrescar = async () => {
    setRefrescando(true);
    await Promise.all([cargar(), recargar()]);
    setRefrescando(false);
  };

  const cambiarRanking = async (participa: boolean) => {
    if (!escuelaId) return;
    setGuardando(true);
    setError(null);
    try {
      await ajustarRanking(escuelaId, participa);
      Haptics.selectionAsync().catch(() => {});
      await recargar();
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setGuardando(false);
    }
  };

  if (!actual) return null;

  return (
    <Screen title="Escuela" subtitle={`${actual.nombre}${actual.ciudad ? ` · ${actual.ciudad}` : ''}`} refreshing={refrescando} onRefresh={refrescar}>
      <SelectorEscuela />
      <Aviso texto={error} />
      <View style={styles.fila}>
        <Iniciales nombre={actual.nombre} color={colors.blue} />
        <Tag texto={esDirector ? 'Director' : 'Entrenador'} tipo="tinta" />
      </View>

      {esDirector && (
        <CodigoCaja
          etiqueta="Código de tu escuela"
          codigo={actual.codigo}
          mensaje={`Únete a ${actual.nombre} en Rankademy con el código ${actual.codigo}`}
          tituloAviso="Código de tu escuela"
        />
      )}

      {!cifras && !error && <Cargando />}
      {cifras && (
        <View style={styles.cifras}>
          <View style={styles.cifra}>
            <Text style={styles.cifraNum}>{cifras.entrenadores}</Text>
            <Text style={styles.cifraEt}>Entrenadores</Text>
          </View>
          <View style={styles.cifra}>
            <Text style={styles.cifraNum}>{cifras.alumnos}</Text>
            <Text style={styles.cifraEt}>Alumnos</Text>
          </View>
        </View>
      )}

      {esDirector && cifras && cifras.solicitudes > 0 && (
        <Button
          label={`${cifras.solicitudes} ${cifras.solicitudes === 1 ? 'solicitud pendiente' : 'solicitudes pendientes'}`}
          variant="dark"
          onPress={() => router.push('/escuela/personas')}
        />
      )}

      <Card>
        <Text style={t.h3}>Ranking</Text>
        <Text style={styles.mut}>Decide si tu escuela compite con las demás.</Text>
        <View style={styles.interruptor}>
          <View style={{ flex: 1 }}>
            <Text style={styles.nombre}>Participar en el ranking</Text>
            <Text style={styles.mut}>{actual.participa_ranking ? 'Activado' : 'Desactivado'}</Text>
          </View>
          <Switch
            value={actual.participa_ranking}
            onValueChange={cambiarRanking}
            disabled={!esDirector || guardando}
            trackColor={{ true: colors.blue, false: colors.line }}
            accessibilityLabel="Participar en el ranking"
          />
        </View>
        <Text style={styles.mut}>
          Si lo desactivas, la escuela sigue usando clases, lista y biblioteca. Solo desaparece de los rankings. Puedes volver a
          activarlo cuando quieras.
        </Text>
        {!esDirector && <Text style={styles.mut}>Solo el director puede cambiar este ajuste.</Text>}
      </Card>

      <Button label="Mis escuelas" variant="ghost" onPress={() => router.push('/mis-escuelas')} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  cifras: { flexDirection: 'row', gap: 12 },
  cifra: { flex: 1, backgroundColor: colors.card, borderRadius: 20, borderWidth: 1, borderColor: colors.line, padding: 16 },
  cifraNum: { fontFamily: fonts.display, fontSize: 48, color: colors.blue },
  cifraEt: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink2 },
  interruptor: { flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 56 },
  nombre: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Redirect, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Screen, Tag } from '@/components';
import { leerBorrador, marcarTerminado } from '@/features/biblioteca/borrador';
import { textoEdad } from '@/features/biblioteca/constantes';
import { Pista } from '@/features/biblioteca/Pista';
import { publicarEjercicio } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { colors, fonts, type as t } from '@/theme';

// El ejercicio se parece a uno de la biblioteca: se ofrece usar el existente o publicar el propio como variante.
export default function YaExiste() {
  const router = useRouter();
  const { borrador, parecidos } = leerBorrador();
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  const mejor = parecidos[0];
  if (!borrador || !mejor) return <Redirect href="/escuela/subir-ejercicio" />;
  // Por encima de este % la base de datos no deja publicarlo si no es como variante
  const bloqueado = mejor.parecido >= 90;
  const edad = textoEdad(mejor.edad_min, mejor.edad_max);

  const publicar = async (originalId?: string) => {
    setError(null);
    setEnviando(true);
    try {
      const id = await publicarEjercicio({ ...borrador, originalId });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      marcarTerminado();
      router.replace({ pathname: '/escuela/ejercicio', params: { id } });
    } catch (e) {
      setError(mensajeError(e));
      setEnviando(false);
    }
  };

  return (
    <Screen back>
      <View style={styles.cabecera}>
        <Text style={[t.h1, { flex: 1 }]} accessibilityRole="header">{'Ya existe uno\nparecido'}</Text>
        <View style={styles.pct}>
          <Text style={styles.pctText}>{mejor.parecido} % igual</Text>
        </View>
      </View>

      <View style={styles.dos}>
        <View style={{ flex: 1, gap: 6 }}>
          <Text style={t.label}>El tuyo</Text>
          <Pista elementos={borrador.imagenes[0]} miniatura />
        </View>
        <View style={{ flex: 1, gap: 6 }}>
          <Text style={t.label}>En la biblioteca</Text>
          <Pista elementos={mejor.dibujo ?? []} miniatura />
        </View>
      </View>

      <Card>
        <Text style={t.h3}>{mejor.titulo}</Text>
        <View style={styles.fila}>
          {!!edad && <Tag texto={`${edad} años`} tipo="azul" />}
          <Tag texto={`${mejor.jugadores_min}-${mejor.jugadores_max} jugadores`} tipo="lima" />
          <Tag texto={mejor.imagenes === 1 ? '1 imagen' : `${mejor.imagenes} imágenes`} tipo="azul" />
        </View>
        <Text style={styles.mut}>
          {mejor.usado_por === 1 ? 'Usado por 1 entrenador' : `Usado por ${mejor.usado_por} entrenadores`}
          {mejor.variantes > 0 ? ` · ${mejor.variantes === 1 ? '1 variante' : `${mejor.variantes} variantes`}` : ''}
        </Text>
      </Card>
      {parecidos.length > 1 && <Text style={styles.mut}>Hay otros {parecidos.length - 1} parecidos en la biblioteca.</Text>}
      <Text style={styles.mut}>
        Si lo publicas como variante, aparece agrupado bajo el original y sus usos se suman a él.
      </Text>

      <Aviso texto={error} />
      <Button
        label="Usar el existente"
        variant="lime"
        onPress={() => {
          marcarTerminado();
          router.replace({ pathname: '/escuela/ejercicio', params: { id: mejor.id } });
        }}
      />
      <Button label="Publicar como variante" variant="ghost" cargando={enviando} onPress={() => publicar(mejor.id)} />
      {!bloqueado && <Button label="No es el mismo: publicar el mío" variant="ghost" small cargando={enviando} onPress={() => publicar()} />}
    </Screen>
  );
}

const styles = StyleSheet.create({
  cabecera: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  pct: { backgroundColor: colors.orangeLight, borderRadius: 999, paddingHorizontal: 12, height: 36, justifyContent: 'center' },
  pctText: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.orangeDark },
  dos: { flexDirection: 'row', gap: 12 },
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

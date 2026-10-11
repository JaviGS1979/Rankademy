import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import { Aviso, Card, Cargando, Screen } from '@/components';
import { Pista } from '@/features/biblioteca/Pista';
import { ejerciciosDeLaClase } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { etiquetaDia, horaCorta } from '@/lib/fechas';
import { usePerfiles } from '@/lib/perfil';
import type { ClaseConEjercicios } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

export default function Ejercicios() {
  const router = useRouter();
  const { activo } = usePerfiles();
  const [clase, setClase] = useState<ClaseConEjercicios | null | undefined>(undefined);
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);

  const cargar = useCallback(async () => {
    if (!activo) return;
    try {
      setClase(await ejerciciosDeLaClase(activo.id));
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [activo]);

  useFocusEffect(
    useCallback(() => {
      cargar();
    }, [cargar]),
  );

  const subtitulo = clase
    ? `Clase de ${etiquetaDia(new Date(`${clase.fecha}T12:00:00`)).toLowerCase()}${clase.grupo ? ` · ${horaCorta(clase.grupo.hora)}` : ''}`
    : undefined;

  return (
    <Screen
      title="Mis ejercicios"
      subtitle={subtitulo}
      refreshing={refrescando}
      onRefresh={async () => {
        setRefrescando(true);
        await cargar();
        setRefrescando(false);
      }}
    >
      <Aviso texto={error} />
      {clase === undefined && !error && <Cargando />}
      {clase === null && (
        <Card>
          <Text style={t.h3}>Aún no hay clase</Text>
          <Text style={styles.mut}>Cuando tu entrenador prepare la próxima clase, verás aquí sus ejercicios.</Text>
        </Card>
      )}
      {clase && clase.ejercicios.length === 0 && (
        <Card>
          <Text style={t.h3}>Sin ejercicios todavía</Text>
          <Text style={styles.mut}>Tu entrenador aún no ha elegido los ejercicios de esta clase.</Text>
        </Card>
      )}
      {clase?.ejercicios.map((e) => (
        <Pressable
          key={e.id}
          accessibilityRole="button"
          accessibilityLabel={`${e.titulo}, ${e.jugadores_min} a ${e.jugadores_max} jugadores`}
          onPress={() => router.push({ pathname: '/alumno/ejercicio', params: { id: e.id } })}
          style={styles.ejercicio}
        >
          <View>
            <Pista elementos={e.dibujo ?? []} miniatura style={{ borderRadius: 0 }} />
            {e.imagenes > 1 && (
              <View style={styles.contador}>
                <Text style={styles.contadorText}>{e.imagenes} imágenes</Text>
              </View>
            )}
          </View>
          <View style={{ padding: 12, gap: 4 }}>
            <Text style={styles.titulo}>{e.titulo}</Text>
            <Text style={styles.mut}>{e.jugadores_min}-{e.jugadores_max} jugadores</Text>
          </View>
        </Pressable>
      ))}
    </Screen>
  );
}

const styles = StyleSheet.create({
  ejercicio: { backgroundColor: colors.white, borderWidth: 1, borderColor: colors.line, borderRadius: 18, overflow: 'hidden' },
  contador: { position: 'absolute', right: 8, bottom: 8, backgroundColor: 'rgba(15,29,46,0.85)', borderRadius: 99, paddingHorizontal: 8, paddingVertical: 2 },
  contadorText: { color: colors.white, fontFamily: fonts.bodyBold, fontSize: 12 },
  titulo: { fontFamily: fonts.display, fontSize: 22, color: colors.ink, textTransform: 'uppercase' },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

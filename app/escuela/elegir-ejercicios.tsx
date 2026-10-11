import { useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, Field, Icon, Screen, Tag } from '@/components';
import { PanelFiltros } from '@/features/biblioteca/PanelFiltros';
import { Tarjeta } from '@/features/biblioteca/Tarjeta';
import { useBiblioteca } from '@/features/biblioteca/useBiblioteca';
import { ejerciciosDeClase, guardarEjerciciosClase, hayFiltros } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { colors, fonts, type as t } from '@/theme';

const MAX = 12;

// Elegir los ejercicios de una clase: los de la biblioteca (y los de mi escuela), en el orden en que se dan.
export default function ElegirEjercicios() {
  const router = useRouter();
  const { sesion } = useLocalSearchParams<{ sesion: string }>();
  const { filtros, setFiltros, items, hayMas, error, verMas, cargandoMas } = useBiblioteca();
  const [elegidos, setElegidos] = useState<{ id: string; titulo: string; retirado: boolean }[] | null>(null);
  const [filtrando, setFiltrando] = useState(false);
  const [aviso, setAviso] = useState<string | null>(null);
  const [guardando, setGuardando] = useState(false);

  useEffect(() => {
    ejerciciosDeClase(sesion)
      .then((l) => setElegidos(l.map((e) => ({ id: e.id, titulo: e.titulo, retirado: e.retirado }))))
      .catch((e) => setAviso(mensajeError(e)));
  }, [sesion]);

  const ids = useMemo(() => new Set((elegidos ?? []).map((e) => e.id)), [elegidos]);

  const alternar = (id: string, titulo: string) => {
    if (!elegidos) return;
    Haptics.selectionAsync().catch(() => {});
    if (ids.has(id)) return setElegidos(elegidos.filter((e) => e.id !== id));
    if (elegidos.length >= MAX) return setAviso(`Como mucho ${MAX} ejercicios por clase.`);
    setAviso(null);
    setElegidos([...elegidos, { id, titulo, retirado: false }]);
  };

  const subir = (i: number) => {
    if (!elegidos || i === 0) return;
    const l = [...elegidos];
    [l[i - 1], l[i]] = [l[i], l[i - 1]];
    setElegidos(l);
  };

  const guardar = async () => {
    if (!elegidos) return;
    setAviso(null);
    setGuardando(true);
    try {
      await guardarEjerciciosClase(sesion, elegidos.map((e) => e.id));
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      router.back();
    } catch (e) {
      setAviso(mensajeError(e));
      setGuardando(false);
    }
  };

  return (
    <Screen back title={'Ejercicios\nde la clase'} subtitle="Toca un ejercicio para añadirlo o quitarlo.">
      <Aviso texto={aviso ?? error} />
      {!elegidos && !aviso && <Cargando />}

      {elegidos && (
        <Card>
          <Text style={t.label} accessibilityRole="header">En esta clase · {elegidos.length}</Text>
          {elegidos.length === 0 && <Text style={styles.mut}>Aún no has elegido ninguno.</Text>}
          {elegidos.map((e, i) => (
            <View key={e.id} style={styles.elegido}>
              <View style={styles.num}>
                <Text style={styles.numText}>{i + 1}</Text>
              </View>
              <View style={{ flex: 1, gap: 4 }}>
                <Text style={styles.titulo} numberOfLines={2}>{e.titulo}</Text>
                {e.retirado && <Tag texto="Retirado de la biblioteca" tipo="naranja" />}
              </View>
              {i > 0 && (
                <Pressable accessibilityRole="button" accessibilityLabel={`Subir ${e.titulo}`} onPress={() => subir(i)} style={styles.mini}>
                  <Text style={styles.miniText}>↑</Text>
                </Pressable>
              )}
              <Pressable accessibilityRole="button" accessibilityLabel={`Quitar ${e.titulo}`} onPress={() => alternar(e.id, e.titulo)} style={styles.mini}>
                <Icon name="close" color={colors.ink2} />
              </Pressable>
            </View>
          ))}
        </Card>
      )}

      <Text style={t.label} accessibilityRole="header">Biblioteca</Text>
      <Field
        label="Buscar"
        placeholder="Nombre del ejercicio"
        value={filtros.texto}
        onChangeText={(texto) => setFiltros({ ...filtros, texto })}
        autoCorrect={false}
      />
      <Button
        label={filtrando ? 'Ocultar filtros' : hayFiltros(filtros) ? 'Filtros (activos)' : 'Filtros'}
        variant={hayFiltros(filtros) ? 'dark' : 'ghost'}
        small
        onPress={() => setFiltrando((v) => !v)}
      />
      {filtrando && <PanelFiltros filtros={filtros} onChange={setFiltros} />}
      {!items && !error && <Cargando />}
      {items?.length === 0 && <Text style={styles.mut}>Ningún ejercicio con esa búsqueda.</Text>}
      <View style={styles.rejilla}>
        {items?.map((e) => (
          <Tarjeta key={e.id} e={e} seleccionada={ids.has(e.id)} onPress={() => alternar(e.id, e.titulo)} />
        ))}
      </View>
      {hayMas && <Button label="Ver más" variant="ghost" small cargando={cargandoMas} onPress={verMas} />}

      <Button label="Guardar clase" variant="lime" onPress={guardar} cargando={guardando} disabled={!elegidos} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  rejilla: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 12 },
  elegido: { flexDirection: 'row', alignItems: 'center', gap: 10, minHeight: 52 },
  num: { width: 36, height: 36, borderRadius: 18, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center' },
  numText: { fontFamily: fonts.display, fontSize: 20, color: colors.lime },
  titulo: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  mini: { width: 44, height: 44, borderRadius: 12, borderWidth: 2, borderColor: colors.line, alignItems: 'center', justifyContent: 'center' },
  miniText: { fontFamily: fonts.bodyBold, fontSize: 20, color: colors.ink },
});

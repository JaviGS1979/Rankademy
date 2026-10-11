import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Chip, Screen } from '@/components';
import { CamposEjercicio, type Textos } from '@/features/biblioteca/CamposEjercicio';
import { EDADES, MAX_IMAGENES } from '@/features/biblioteca/constantes';
import { consumirTerminado, guardarBorrador } from '@/features/biblioteca/borrador';
import { PistaEditor } from '@/features/biblioteca/PistaEditor';
import { Stepper } from '@/features/biblioteca/Stepper';
import { buscarParecidos, publicarEjercicio, type DatosEjercicio } from '@/lib/api';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import type { Elemento } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

// Nuevo ejercicio: se dibuja sobre la pista (hasta 5 imágenes), se rellenan los datos y se publica.
// Antes de publicar en la biblioteca pública se comprueba si ya existe uno parecido.
export default function SubirEjercicio() {
  const router = useRouter();
  const { escuelas, actual } = useEscuela();
  const [imagenes, setImagenes] = useState<Elemento[][]>([[]]);
  const [actualImg, setActualImg] = useState(0);
  const [textos, setTextos] = useState<Textos>({ titulo: '', nivel: null, objetivo: null, espacio: null, material: [], pasos: [] });
  const [jugMin, setJugMin] = useState(4);
  const [jugMax, setJugMax] = useState(8);
  const [edad, setEdad] = useState<string>('8-13');
  const [soloEscuela, setSoloEscuela] = useState(false);
  const [escuelaId, setEscuelaId] = useState<string | null>(actual?.id ?? null);
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  // Si se publicó (o se eligió el existente) desde "Ya existe uno parecido", este formulario sobra
  useFocusEffect(
    useCallback(() => {
      if (consumirTerminado()) router.canGoBack() ? router.back() : router.replace('/escuela/biblioteca');
    }, [router]),
  );

  const ponerImagen = (e: Elemento[]) => setImagenes((l) => l.map((x, i) => (i === actualImg ? e : x)));
  const anadirImagen = () => {
    if (imagenes.length >= MAX_IMAGENES) return;
    setImagenes((l) => [...l, []]);
    setActualImg(imagenes.length);
  };
  const quitarImagen = () => {
    if (imagenes.length <= 1) return;
    setImagenes((l) => l.filter((_, i) => i !== actualImg));
    setActualImg((i) => Math.max(0, i - 1));
  };

  const publicar = async () => {
    setError(null);
    const rango = EDADES.find((e) => e.id === edad)!;
    if (imagenes.some((i) => i.length === 0)) return setError('Cada imagen necesita al menos un elemento. Dibuja algo o quita la imagen vacía.');
    if (textos.titulo.trim().length < 2) return setError('Ponle un nombre al ejercicio.');
    if (soloEscuela && !escuelaId) return setError('Elige para qué escuela es.');
    const datos: DatosEjercicio = {
      titulo: textos.titulo,
      visibilidad: soloEscuela ? 'escuela' : 'publica',
      escuelaId: soloEscuela ? escuelaId : null,
      jugMin,
      jugMax,
      edadMin: rango.min,
      edadMax: rango.max,
      nivel: textos.nivel,
      objetivo: textos.objetivo,
      espacio: textos.espacio,
      material: textos.material,
      pasos: textos.pasos,
      imagenes,
    };
    setEnviando(true);
    try {
      if (!soloEscuela) {
        const parecidos = await buscarParecidos(datos);
        if (parecidos.length > 0) {
          guardarBorrador(datos, parecidos);
          setEnviando(false);
          return router.push('/escuela/ya-existe');
        }
      }
      const id = await publicarEjercicio(datos);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      router.replace({ pathname: '/escuela/ejercicio', params: { id } });
    } catch (e) {
      setError(mensajeError(e));
      setEnviando(false);
    }
  };

  return (
    <Screen back title={'Nuevo\nejercicio'}>
      <PistaEditor elementos={imagenes[actualImg]} onChange={ponerImagen} />

      <View style={styles.fila} accessibilityRole="radiogroup">
        {imagenes.map((_, i) => (
          <Chip key={i} texto={`Imagen ${i + 1}`} on={i === actualImg} onPress={() => setActualImg(i)} />
        ))}
        {imagenes.length < MAX_IMAGENES && (
          <Pressable accessibilityRole="button" onPress={anadirImagen} style={styles.anadir}>
            <Text style={styles.anadirText}>+ Añadir imagen</Text>
          </Pressable>
        )}
      </View>
      {imagenes.length > 1 && <Button label={`Quitar la imagen ${actualImg + 1}`} variant="ghost" small onPress={quitarImagen} />}

      <CamposEjercicio valor={textos} onChange={setTextos} />

      <View style={{ gap: 6 }}>
        <Text style={styles.label}>Jugadores: entre</Text>
        <View style={styles.entre}>
          <Stepper label="jugadores mínimo" value={jugMin} min={1} max={jugMax} onChange={setJugMin} />
          <Text style={styles.y}>y</Text>
          <Stepper label="jugadores máximo" value={jugMax} min={jugMin} max={30} onChange={setJugMax} />
        </View>
      </View>

      <View style={{ gap: 6 }}>
        <Text style={styles.label}>Edad</Text>
        <View style={styles.fila} accessibilityRole="radiogroup">
          {EDADES.map((e) => (
            <Chip key={e.id} texto={e.id} on={edad === e.id} onPress={() => setEdad(e.id)} />
          ))}
        </View>
      </View>

      <View style={styles.seg} accessibilityRole="radiogroup">
        <Pressable accessibilityRole="radio" accessibilityState={{ selected: !soloEscuela }} onPress={() => setSoloEscuela(false)} style={[styles.segOp, !soloEscuela && styles.segOn]}>
          <Text style={styles.segText}>Biblioteca pública</Text>
        </Pressable>
        <Pressable accessibilityRole="radio" accessibilityState={{ selected: soloEscuela }} onPress={() => setSoloEscuela(true)} style={[styles.segOp, soloEscuela && styles.segOn]}>
          <Text style={styles.segText}>Solo mi escuela</Text>
        </Pressable>
      </View>
      {soloEscuela && escuelas.length > 1 && (
        <View style={styles.fila} accessibilityRole="radiogroup">
          {escuelas.map((e) => (
            <Chip key={e.id} texto={e.nombre} on={escuelaId === e.id} onPress={() => setEscuelaId(e.id)} />
          ))}
        </View>
      )}
      <Text style={styles.nota}>
        {soloEscuela
          ? 'Solo lo ve el personal de esa escuela y no cuenta para el ranking.'
          : 'Pública: anónima, la ven todos los entrenadores. Nadie sabrá que lo subiste tú.'}
      </Text>

      <Aviso texto={error} />
      <Button label="Publicar" variant="lime" onPress={publicar} cargando={enviando} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  entre: { flexDirection: 'row', alignItems: 'center', gap: 10, flexWrap: 'wrap' },
  y: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  label: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  anadir: { minHeight: 44, paddingHorizontal: 16, borderRadius: 999, borderWidth: 2, borderStyle: 'dashed', borderColor: colors.ink2, justifyContent: 'center' },
  anadirText: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.ink },
  seg: { flexDirection: 'row', backgroundColor: colors.line, borderRadius: 14, padding: 4, gap: 4 },
  segOp: { flex: 1, minHeight: 44, borderRadius: 11, alignItems: 'center', justifyContent: 'center' },
  segOn: { backgroundColor: colors.white },
  segText: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  nota: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

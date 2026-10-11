import { useEffect, useState } from 'react';
import { Text } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Cargando, Screen } from '@/components';
import { CamposEjercicio, type Textos } from '@/features/biblioteca/CamposEjercicio';
import { detalleEjercicio, editarEjercicio } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { colors, fonts } from '@/theme';

// Cambiar los textos de un ejercicio propio (el dibujo, los jugadores y la edad no se tocan)
export default function EditarEjercicio() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const [textos, setTextos] = useState<Textos | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  useEffect(() => {
    detalleEjercicio(id)
      .then((d) => {
        if (!d.es_mio) throw new Error('Solo el autor puede editar este ejercicio');
        setTextos({ titulo: d.titulo, nivel: d.nivel, objetivo: d.objetivo, espacio: d.espacio, material: d.material, pasos: d.pasos });
      })
      .catch((e) => setError(mensajeError(e)));
  }, [id]);

  const guardar = async () => {
    if (!textos) return;
    setError(null);
    if (textos.titulo.trim().length < 2) return setError('Ponle un nombre al ejercicio.');
    setEnviando(true);
    try {
      await editarEjercicio(id, textos);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      router.back();
    } catch (e) {
      setError(mensajeError(e));
      setEnviando(false);
    }
  };

  return (
    <Screen back title={'Editar\nejercicio'}>
      {!textos && !error && <Cargando />}
      <Aviso texto={error} />
      {textos && (
        <>
          <CamposEjercicio valor={textos} onChange={setTextos} />
          <Text style={{ fontFamily: fonts.body, fontSize: 14, color: colors.ink2 }}>
            El dibujo, los jugadores y la edad no se cambian una vez publicado.
          </Text>
          <Button label="Guardar cambios" variant="lime" onPress={guardar} cargando={enviando} />
        </>
      )}
    </Screen>
  );
}

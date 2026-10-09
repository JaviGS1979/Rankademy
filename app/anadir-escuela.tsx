import { useCallback, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Chip, Field, Screen } from '@/components';
import { misPerfiles, unirseAEscuela } from '@/lib/api';
import { codigoValido, mensajeError, normalizarCodigo } from '@/lib/errores';
import type { Perfil } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

const PASOS = [
  'Escribe el código que te da la dirección',
  'El director aprueba tu acceso',
  'La escuela aparece en Mis escuelas',
];

export default function AnadirEscuela() {
  const router = useRouter();
  const p = useLocalSearchParams<{ error?: string; codigo?: string; perfil?: string }>();
  const [codigo, setCodigo] = useState(normalizarCodigo(p.codigo ?? ''));
  // 'entrenador' o el id de un perfil de hijo
  const [quien, setQuien] = useState<string>(p.perfil ?? 'entrenador');
  const [perfiles, setPerfiles] = useState<Perfil[]>([]);
  const [error, setError] = useState<string | null>(p.error ?? null);
  const [enviando, setEnviando] = useState(false);

  useFocusEffect(
    useCallback(() => {
      misPerfiles().then(setPerfiles).catch(() => {});
    }, []),
  );

  const pedir = async () => {
    setError(null);
    if (!codigoValido(codigo)) return setError('El código tiene este formato: A7K-29Q.');
    setEnviando(true);
    try {
      if (quien === 'entrenador') await unirseAEscuela(codigo, 'entrenador');
      else await unirseAEscuela(codigo, 'alumno', quien);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      router.replace('/mis-escuelas');
    } catch (e) {
      setError(mensajeError(e));
      setEnviando(false);
    }
  };

  return (
    <Screen back title={'Añadir otra\nescuela'}>
      <Field
        label="Código de la escuela"
        code
        placeholder="Ej. A7K-29Q"
        value={codigo}
        onChangeText={(v) => setCodigo(normalizarCodigo(v))}
        autoCapitalize="characters"
        autoCorrect={false}
        maxLength={7}
      />

      <View style={{ gap: 8 }}>
        <Text style={styles.label}>¿Para quién?</Text>
        <View style={styles.chips} accessibilityRole="radiogroup">
          <Chip texto="Yo, como entrenador" on={quien === 'entrenador'} onPress={() => setQuien('entrenador')} />
          {perfiles.map((pf) => (
            <Chip key={pf.id} texto={pf.nombre} on={quien === pf.id} onPress={() => setQuien(pf.id)} />
          ))}
          <Chip
            texto="+ Añadir hijo"
            onPress={() => router.push({ pathname: '/anadir-hijo', params: codigoValido(codigo) ? { codigo } : {} })}
          />
        </View>
      </View>

      <View style={{ gap: 12 }}>
        {PASOS.map((t, i) => (
          <View key={t} style={styles.paso}>
            <View style={styles.n}>
              <Text style={styles.nText}>{i + 1}</Text>
            </View>
            <Text style={styles.pasoText}>{t}</Text>
          </View>
        ))}
      </View>

      <Text style={styles.nota}>
        Seguirás en tus otras escuelas. Si coinciden dos clases a la misma hora, te avisamos.
      </Text>
      <Aviso texto={error} />
      <Button label="Pedir acceso" variant="lime" onPress={pedir} cargando={enviando} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  label: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  paso: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  n: { width: 44, height: 44, borderRadius: 22, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center' },
  nText: { fontFamily: fonts.display, fontSize: 26, color: colors.lime },
  pasoText: { flex: 1, fontFamily: fonts.bodySemi, fontSize: 16, color: colors.ink },
  nota: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

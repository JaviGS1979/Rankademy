import { useState } from 'react';
import { Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Field, Screen } from '@/components';
import { vincularAlumno } from '@/lib/api';
import { avisar } from '@/lib/avisar';
import { codigoAlumnoValido, mensajeError, normalizarCodigoAlumno } from '@/lib/errores';
import { usePerfiles } from '@/lib/perfil';
import { TEXTO_CONSENTIMIENTO } from '@/lib/textos';
import { colors, fonts } from '@/theme';

// La familia vincula a su hijo, que la escuela ya inscribió, con el código que le dieron.
export default function VincularAlumno() {
  const router = useRouter();
  const { recargar, elegir } = usePerfiles();
  const [codigo, setCodigo] = useState('');
  const [acepto, setAcepto] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  const vincular = async () => {
    setError(null);
    if (!codigoAlumnoValido(codigo)) return setError('El código tiene este formato: K7PA-3QXM.');
    if (!acepto) return setError('Para vincular al alumno hace falta tu consentimiento.');
    setEnviando(true);
    try {
      const r = await vincularAlumno(codigo, true);
      await recargar();
      elegir(r.perfil_id);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      router.replace('/inicio');
    } catch (e) {
      setError(mensajeError(e));
      setEnviando(false);
    }
  };

  return (
    <Screen back title={'Vincular\nalumno'} subtitle="La escuela ya inscribió a tu hijo. Escribe el código que te dieron.">
      <Field
        label="Código del alumno"
        placeholder="K7PA-3QXM"
        value={codigo}
        onChangeText={(v) => setCodigo(normalizarCodigoAlumno(v))}
        autoCapitalize="characters"
        autoCorrect={false}
        maxLength={9}
        code
        returnKeyType="go"
        onSubmitEditing={vincular}
      />

      <View style={styles.consent}>
        <Switch
          value={acepto}
          onValueChange={setAcepto}
          trackColor={{ true: colors.blue, false: colors.line }}
          accessibilityLabel="Acepto el consentimiento"
        />
        <View style={{ flex: 1, gap: 6 }}>
          <Text style={styles.consentText}>
            Soy el adulto responsable y acepto el consentimiento para vincular este perfil de menor.
          </Text>
          <Pressable accessibilityRole="link" onPress={() => avisar('Consentimiento', TEXTO_CONSENTIMIENTO)} hitSlop={10}>
            <Text style={styles.link}>Leer texto</Text>
          </Pressable>
        </View>
      </View>

      <Aviso texto={error} />
      <Button label="Vincular alumno" variant="lime" onPress={vincular} cargando={enviando} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  consent: { flexDirection: 'row', gap: 12, alignItems: 'flex-start', backgroundColor: colors.card, borderRadius: 16, borderWidth: 1, borderColor: colors.line, padding: 14 },
  consentText: { fontFamily: fonts.bodySemi, fontSize: 15, color: colors.ink },
  link: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.blue, textDecorationLine: 'underline' },
});

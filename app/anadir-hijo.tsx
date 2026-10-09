import { useState } from 'react';
import { Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Field, Screen } from '@/components';
import { crearPerfil, unirseAEscuela } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { avisar } from '@/lib/avisar';
import { colors, fonts } from '@/theme';

const EDAD_MIN = 3;
const EDAD_MAX = 17;

// Texto provisional: pendiente de revisión legal antes del lanzamiento.
const TEXTO_CONSENTIMIENTO =
  'Como adulto responsable, autorizo a Rankademy a tratar el nombre o alias y el año de nacimiento de este menor ' +
  'para registrar su asistencia a clase, su progreso y, si lo permito, su posición en los rankings con nombre de pila ' +
  'o alias y avatar (nunca foto real). Puedo retirar el perfil del ranking o borrarlo en cualquier momento.';

export default function AnadirHijo() {
  const router = useRouter();
  const { codigo } = useLocalSearchParams<{ codigo?: string }>();
  const [nombre, setNombre] = useState('');
  const [anio, setAnio] = useState('');
  const [acepto, setAcepto] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  const anioActual = new Date().getFullYear();
  const edad = /^\d{4}$/.test(anio) ? anioActual - Number(anio) : null;
  const nivel = edad === null ? null : edad <= 7 ? 'Mini' : edad <= 13 ? 'Gamer' : 'Junior';

  const guardar = async () => {
    setError(null);
    if (nombre.trim().length < 2) return setError('Escribe el nombre o alias.');
    if (edad === null || edad < EDAD_MIN || edad > EDAD_MAX)
      return setError(`El año debe corresponder a una edad de ${EDAD_MIN} a ${EDAD_MAX} años.`);
    if (!acepto) return setError('Para crear el perfil hace falta tu consentimiento.');
    setEnviando(true);
    let perfilId: string;
    try {
      perfilId = (await crearPerfil(nombre, Number(anio))).id;
    } catch (e) {
      setError(mensajeError(e));
      setEnviando(false);
      return;
    }
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
    if (!codigo) return router.replace('/mis-escuelas');
    try {
      await unirseAEscuela(codigo, 'alumno', perfilId);
      router.replace('/mis-escuelas');
    } catch (e) {
      // El perfil ya está creado: se reintenta solo la unión, sin duplicarlo
      router.replace({ pathname: '/anadir-escuela', params: { error: mensajeError(e), codigo, perfil: perfilId } });
    }
  };

  return (
    <Screen back title={'Añadir\nun hijo'} subtitle="Solo pedimos lo mínimo.">
      <Field label="Nombre" placeholder="Nombre o alias" value={nombre} onChangeText={setNombre} autoCapitalize="words" maxLength={40} />
      <Field
        label="Año de nacimiento"
        placeholder={`Ej. ${anioActual - 9}`}
        value={anio}
        onChangeText={(v) => setAnio(v.replace(/\D/g, '').slice(0, 4))}
        keyboardType="number-pad"
        maxLength={4}
      />
      <Text style={styles.nota}>
        {nivel
          ? `Se creará un perfil ${nivel}.`
          : 'Según la edad se crea el perfil Mini (3-7), Gamer (8-13) o Junior (14-17).'}
      </Text>

      <View style={styles.consent}>
        <Switch
          value={acepto}
          onValueChange={setAcepto}
          trackColor={{ true: colors.blue, false: colors.line }}
          accessibilityLabel="Acepto el consentimiento"
        />
        <View style={{ flex: 1, gap: 6 }}>
          <Text style={styles.consentText}>
            Soy el adulto responsable y acepto el consentimiento para crear este perfil de menor.
          </Text>
          <Pressable accessibilityRole="link" onPress={() => avisar('Consentimiento', TEXTO_CONSENTIMIENTO)} hitSlop={10}>
            <Text style={styles.link}>Leer texto</Text>
          </Pressable>
        </View>
      </View>

      <Aviso texto={error} />
      <Button label="Añadir hijo" variant="lime" onPress={guardar} cargando={enviando} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  nota: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  consent: { flexDirection: 'row', gap: 12, alignItems: 'flex-start', backgroundColor: colors.card, borderRadius: 16, borderWidth: 1, borderColor: colors.line, padding: 14 },
  consentText: { fontFamily: fonts.bodySemi, fontSize: 15, color: colors.ink },
  link: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.blue, textDecorationLine: 'underline' },
});

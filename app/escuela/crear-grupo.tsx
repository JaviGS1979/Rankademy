import { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Redirect, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Chip, Field, Screen } from '@/components';
import { crearGrupo, entrenadoresDeEscuela } from '@/lib/api';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import { horaValida } from '@/lib/fechas';
import type { EntrenadorEscuela } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

const DIAS = [
  { n: 1, corto: 'L', largo: 'Lunes' },
  { n: 2, corto: 'M', largo: 'Martes' },
  { n: 3, corto: 'X', largo: 'Miércoles' },
  { n: 4, corto: 'J', largo: 'Jueves' },
  { n: 5, corto: 'V', largo: 'Viernes' },
  { n: 6, corto: 'S', largo: 'Sábado' },
  { n: 7, corto: 'D', largo: 'Domingo' },
];

export default function CrearGrupo() {
  const router = useRouter();
  const { actual, esDirector } = useEscuela();
  const [nombre, setNombre] = useState('');
  const [dia, setDia] = useState<number | null>(null);
  const [hora, setHora] = useState('');
  const [pista, setPista] = useState('');
  const [entrenador, setEntrenador] = useState<string | null>(null);
  const [entrenadores, setEntrenadores] = useState<EntrenadorEscuela[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);
  const escuelaId = actual?.id;

  useEffect(() => {
    if (!escuelaId) return;
    entrenadoresDeEscuela(escuelaId).then(setEntrenadores).catch(() => {});
  }, [escuelaId]);

  if (!esDirector) return <Redirect href="/escuela" />;

  const crear = async () => {
    setError(null);
    const horaOk = horaValida(hora);
    if (nombre.trim().length < 2) return setError('Ponle un nombre al grupo.');
    if (!dia) return setError('Elige el día de la semana.');
    if (!horaOk) return setError('La hora tiene este formato: 17:00.');
    if (!escuelaId) return;
    setEnviando(true);
    try {
      await crearGrupo({ escuelaId, nombre, dia, hora: horaOk, pista, entrenadorId: entrenador });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      router.back();
    } catch (e) {
      setError(mensajeError(e));
      setEnviando(false);
    }
  };

  return (
    <Screen back title={'Crear\ngrupo'}>
      <Field
        label="Nombre del grupo"
        placeholder="Ej. Los Tigres"
        value={nombre}
        onChangeText={setNombre}
        autoCapitalize="sentences"
        maxLength={60}
      />

      <View style={{ gap: 6 }}>
        <Text style={styles.label}>Día</Text>
        <View style={styles.fila} accessibilityRole="radiogroup">
          {DIAS.map((d) => (
            <Chip key={d.n} texto={d.corto} etiqueta={d.largo} on={dia === d.n} onPress={() => setDia(d.n)} />
          ))}
        </View>
      </View>

      <Field
        label="Hora"
        placeholder="17:00"
        value={hora}
        onChangeText={(v) => setHora(v.replace(/[^0-9:.hH]/g, '').slice(0, 5))}
        keyboardType="numbers-and-punctuation"
        maxLength={5}
      />
      <Field label="Pista (opcional)" placeholder="Ej. 2" value={pista} onChangeText={setPista} maxLength={20} />

      <View style={{ gap: 6 }}>
        <Text style={styles.label}>Entrenador (opcional)</Text>
        <View style={styles.fila} accessibilityRole="radiogroup">
          <Chip texto="Sin asignar" on={entrenador === null} onPress={() => setEntrenador(null)} />
          {entrenadores.map((e) => (
            <Chip key={e.persona_id} texto={e.nombre} on={entrenador === e.persona_id} onPress={() => setEntrenador(e.persona_id)} />
          ))}
        </View>
        {entrenadores.length === 0 && (
          <Text style={styles.nota}>Los entrenadores se unen con el código de la escuela y tú los apruebas en Personas.</Text>
        )}
      </View>

      <Text style={styles.nota}>
        Cada grupo es un día y una hora. Para dar clase otro día, crea otro grupo. Un entrenador puede no tener grupo asignado.
      </Text>
      <Aviso texto={error} />
      <Button label="Crear grupo" variant="lime" onPress={crear} cargando={enviando} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  label: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  nota: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

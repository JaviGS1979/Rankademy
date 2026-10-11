import { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Redirect, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Chip, CodigoCaja, Field, Screen } from '@/components';
import { altaAlumno, gruposDeEscuela } from '@/lib/api';
import { useEscuela } from '@/lib/escuela';
import { mensajeError } from '@/lib/errores';
import { horaCorta, nombreDia } from '@/lib/fechas';
import type { GrupoEscuela } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

const EDAD_MIN = 3;
const EDAD_MAX = 17;

// El director inscribe a un alumno y recibe un código para dárselo a su familia.
export default function AltaAlumno() {
  const router = useRouter();
  const { actual, esDirector } = useEscuela();
  const [nombre, setNombre] = useState('');
  const [apellidos, setApellidos] = useState('');
  const [anio, setAnio] = useState('');
  const [grupos, setGrupos] = useState<GrupoEscuela[]>([]);
  const [elegidos, setElegidos] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);
  const [resultado, setResultado] = useState<{ nombre: string; codigo: string } | null>(null);
  const escuelaId = actual?.id;

  useEffect(() => {
    if (!escuelaId) return;
    gruposDeEscuela(escuelaId).then(setGrupos).catch(() => {});
  }, [escuelaId]);

  if (!esDirector) return <Redirect href="/escuela" />;

  const anioActual = new Date().getFullYear();
  const edad = /^\d{4}$/.test(anio) ? anioActual - Number(anio) : null;

  const dias = new Set(grupos.filter((g) => elegidos.includes(g.id)).map((g) => g.dia)).size;

  const alternar = (id: string) =>
    setElegidos((l) => (l.includes(id) ? l.filter((x) => x !== id) : [...l, id]));

  const inscribir = async () => {
    setError(null);
    if (nombre.trim().length < 2) return setError('Escribe el nombre del alumno.');
    if (edad === null || edad < EDAD_MIN || edad > EDAD_MAX)
      return setError(`El año debe corresponder a una edad de ${EDAD_MIN} a ${EDAD_MAX} años.`);
    if (!escuelaId) return;
    setEnviando(true);
    try {
      const r = await altaAlumno({ escuelaId, nombre, apellidos, anio: Number(anio), grupos: elegidos });
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      setResultado({ nombre: nombre.trim(), codigo: r.codigo });
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setEnviando(false);
    }
  };

  const otro = () => {
    setResultado(null);
    setNombre('');
    setApellidos('');
    setAnio('');
    setElegidos([]);
  };

  if (resultado) {
    return (
      <Screen title={'Alumno\ninscrito'}>
        <Card>
          <Text style={t.h3}>{resultado.nombre} ya está en la escuela</Text>
          <Text style={styles.mut}>
            Dale este código a su familia. Con él vinculan al alumno a su cuenta, aceptan el consentimiento y pueden confirmar su
            asistencia. Hasta entonces, no suma XP.
          </Text>
        </Card>
        <CodigoCaja
          etiqueta={`Código de ${resultado.nombre}`}
          codigo={resultado.codigo}
          mensaje={`Vincula a ${resultado.nombre} en Rankademy: entra en la app, pulsa "Tengo un código de alumno" y escribe ${resultado.codigo}`}
          tituloAviso="Código del alumno"
        />
        <Text style={styles.mut}>Lo puedes volver a ver en Personas.</Text>
        <Button label="Inscribir a otro alumno" variant="dark" onPress={otro} />
        <Button label="Listo" variant="lime" onPress={() => router.back()} />
      </Screen>
    );
  }

  return (
    <Screen back title={'Inscribir\nalumno'}>
      <Field label="Nombre" placeholder="Nombre" value={nombre} onChangeText={setNombre} autoCapitalize="words" maxLength={40} />
      <Field label="Apellidos" placeholder="Apellidos" value={apellidos} onChangeText={setApellidos} autoCapitalize="words" maxLength={60} />
      <Field
        label="Año de nacimiento"
        placeholder={`Ej. ${anioActual - 9}`}
        value={anio}
        onChangeText={(v) => setAnio(v.replace(/\D/g, '').slice(0, 4))}
        keyboardType="number-pad"
        maxLength={4}
      />

      <View style={{ gap: 6 }}>
        <Text style={styles.label}>Grupos (día y hora)</Text>
        <Text style={styles.mut}>Elige uno o varios.</Text>
        {grupos.length === 0 && <Text style={styles.mut}>Aún no hay grupos: crea uno en Horario y apúntalo después.</Text>}
        <View style={styles.fila}>
          {grupos.map((g) => (
            <Chip
              key={g.id}
              texto={`${g.nombre} · ${nombreDia(g.dia).slice(0, 3)} ${horaCorta(g.hora)}`}
              on={elegidos.includes(g.id)}
              onPress={() => alternar(g.id)}
            />
          ))}
        </View>
        {dias > 0 && <Text style={styles.mut}>{dias === 1 ? '1 día a la semana' : `${dias} días a la semana`}</Text>}
      </View>

      <Aviso texto={error} />
      <Button label="Inscribir" variant="lime" onPress={inscribir} cargando={enviando} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  label: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
});

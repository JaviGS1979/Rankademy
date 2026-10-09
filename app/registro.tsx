import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Aviso, Button, Field, Screen } from '@/components';
import { enviarCodigo } from '@/lib/api';
import { codigoValido, correoValido, mensajeError, normalizarCodigo } from '@/lib/errores';
import { colors, fonts } from '@/theme';
import { avisar } from '@/lib/avisar';

type Rol = 'director' | 'entrenador' | 'alumno';

export default function Registro() {
  const router = useRouter();
  const params = useLocalSearchParams<{ rol?: Rol }>();
  const rol: Rol = params.rol === 'director' || params.rol === 'alumno' ? params.rol : 'entrenador';
  const esDirector = rol === 'director';

  const [codigo, setCodigo] = useState('');
  const [nombre, setNombre] = useState('');
  const [correo, setCorreo] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  const entrar = async () => {
    setError(null);
    if (!esDirector && !codigoValido(codigo)) return setError('El código tiene este formato: A7K-29Q.');
    if (nombre.trim().length < 2) return setError('Escribe tu nombre.');
    if (!correoValido(correo)) return setError('Escribe un correo válido.');
    setEnviando(true);
    try {
      await enviarCodigo(correo, { crear: true, nombre });
      router.push({
        pathname: '/verificar',
        params: { correo: correo.trim().toLowerCase(), nombre: nombre.trim(), rol, codigo: esDirector ? '' : codigo },
      });
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setEnviando(false);
    }
  };

  const pronto = () => avisar('Muy pronto', 'De momento entra con tu correo.');

  return (
    <Screen back title={esDirector ? 'Crea tu\ncuenta' : 'Entra en\ntu escuela'}>
      {!esDirector && (
        <Field
          label="Código de escuela"
          code
          placeholder="Ej. A7K-29Q"
          value={codigo}
          onChangeText={(v) => setCodigo(normalizarCodigo(v))}
          autoCapitalize="characters"
          autoCorrect={false}
          maxLength={7}
        />
      )}
      <Field
        label={rol === 'alumno' ? 'Tu nombre (adulto responsable)' : 'Tu nombre'}
        placeholder="Nombre y apellido"
        value={nombre}
        onChangeText={setNombre}
        autoCapitalize="words"
        autoComplete="name"
        textContentType="name"
        maxLength={80}
      />
      <Field
        label="Correo"
        placeholder="nombre@correo.com"
        value={correo}
        onChangeText={setCorreo}
        keyboardType="email-address"
        autoCapitalize="none"
        autoComplete="email"
        textContentType="emailAddress"
        returnKeyType="go"
        onSubmitEditing={entrar}
      />
      <Aviso texto={error} />
      <Button label="Entrar" variant="lime" onPress={entrar} cargando={enviando} />

      <View style={styles.or}>
        <View style={styles.line} />
        <Text style={styles.orText}>o</Text>
        <View style={styles.line} />
      </View>

      <View style={{ gap: 12 }}>
        <Button label="Continuar con Apple" variant="ghost" onPress={pronto} />
        <Button label="Continuar con Google" variant="ghost" onPress={pronto} />
      </View>

      <Text style={styles.note}>
        {esDirector
          ? 'Te enviaremos un código al correo. Después creas tu escuela.'
          : 'Tres campos y listo. El código te lo da tu escuela.'}
      </Text>
    </Screen>
  );
}

const styles = StyleSheet.create({
  or: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  line: { flex: 1, height: 1, backgroundColor: colors.line },
  orText: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink2 },
  note: { fontFamily: fonts.body, fontSize: 13, color: colors.ink2, textAlign: 'center', marginTop: 'auto' },
});

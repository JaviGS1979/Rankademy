import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Button, Field, Screen } from '@/components';
import { colors, fonts } from '@/theme';

export default function Registro() {
  const router = useRouter();
  const [codigo, setCodigo] = useState('');
  const [nombre, setNombre] = useState('');
  const [correo, setCorreo] = useState('');

  // La autenticación real con Supabase llega en la Fase 3.
  const entrar = () => router.replace('/inicio');

  return (
    <Screen back title={'Entra en\ntu escuela'}>
      <Field
        label="Código de escuela"
        code
        placeholder="Ej. A7K-29Q"
        value={codigo}
        onChangeText={(v) => setCodigo(v.toUpperCase())}
        autoCapitalize="characters"
        autoCorrect={false}
        maxLength={7}
      />
      <Field
        label="Tu nombre"
        placeholder="Nombre y apellido"
        value={nombre}
        onChangeText={setNombre}
        autoCapitalize="words"
        autoComplete="name"
        textContentType="name"
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
      />
      <Button label="Entrar" variant="lime" onPress={entrar} />

      <View style={styles.or}>
        <View style={styles.line} />
        <Text style={styles.orText}>o</Text>
        <View style={styles.line} />
      </View>

      <View style={{ gap: 12 }}>
        <Button label="Continuar con Apple" variant="ghost" onPress={entrar} />
        <Button label="Continuar con Google" variant="ghost" onPress={entrar} />
      </View>

      <Text style={styles.note}>Tres campos y listo. El código te lo da tu escuela.</Text>
    </Screen>
  );
}

const styles = StyleSheet.create({
  or: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  line: { flex: 1, height: 1, backgroundColor: colors.line },
  orText: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink2 },
  note: { fontFamily: fonts.body, fontSize: 13, color: colors.ink2, textAlign: 'center', marginTop: 'auto' },
});

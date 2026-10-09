import { useState } from 'react';
import { useRouter } from 'expo-router';
import { Aviso, Button, Field, Screen } from '@/components';
import { enviarCodigo } from '@/lib/api';
import { correoValido, mensajeError } from '@/lib/errores';

// "Ya tengo cuenta": solo el correo; no crea cuentas nuevas.
export default function Entrar() {
  const router = useRouter();
  const [correo, setCorreo] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  const enviar = async () => {
    setError(null);
    if (!correoValido(correo)) return setError('Escribe un correo válido.');
    setEnviando(true);
    try {
      await enviarCodigo(correo, { crear: false });
      router.push({ pathname: '/verificar', params: { correo: correo.trim().toLowerCase() } });
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setEnviando(false);
    }
  };

  return (
    <Screen back title={'Hola de\nnuevo'} subtitle="Te enviaremos un código a tu correo.">
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
        onSubmitEditing={enviar}
        autoFocus
      />
      <Aviso texto={error} />
      <Button label="Enviar código" variant="lime" onPress={enviar} cargando={enviando} />
    </Screen>
  );
}

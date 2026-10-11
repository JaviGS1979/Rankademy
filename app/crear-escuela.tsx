import { useState } from 'react';
import { Text } from 'react-native';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Field, Screen } from '@/components';
import { crearEscuela } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { colors, fonts } from '@/theme';

export default function CrearEscuela() {
  const router = useRouter();
  const [nombre, setNombre] = useState('');
  const [ciudad, setCiudad] = useState('');
  const [provincia, setProvincia] = useState('');
  const [comunidad, setComunidad] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  const crear = async () => {
    setError(null);
    if (nombre.trim().length < 2) return setError('Escribe el nombre de la escuela.');
    if (ciudad.trim().length < 2) return setError('Escribe la ciudad.');
    setEnviando(true);
    try {
      const escuela = await crearEscuela(nombre, ciudad, provincia, comunidad);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      router.replace({ pathname: '/mis-escuelas', params: { nueva: escuela.id } });
    } catch (e) {
      setError(mensajeError(e));
      setEnviando(false);
    }
  };

  return (
    <Screen back title={'Crea tu\nescuela'} subtitle="Al terminar recibirás un código único para compartir.">
      <Field
        label="Nombre de la escuela"
        placeholder="Nombre de tu escuela"
        value={nombre}
        onChangeText={setNombre}
        autoCapitalize="words"
        maxLength={80}
      />
      <Field
        label="Ciudad"
        placeholder="Ciudad"
        value={ciudad}
        onChangeText={setCiudad}
        autoCapitalize="words"
        autoComplete="postal-address-locality"
        textContentType="addressCity"
        returnKeyType="go"
        onSubmitEditing={crear}
        maxLength={60}
      />
      <Field label="Provincia" placeholder="Ej. Huelva" value={provincia} onChangeText={setProvincia} autoCapitalize="words" maxLength={60} />
      <Field label="Comunidad" placeholder="Ej. Andalucía" value={comunidad} onChangeText={setComunidad} autoCapitalize="words" maxLength={60} />
      <Text style={{ fontFamily: fonts.body, fontSize: 14, color: colors.ink2 }}>
        La provincia y la comunidad sirven para el ranking de tu zona. Puedes cambiarlas después. El logo es opcional: podrás añadirlo después desde el panel.
      </Text>
      <Aviso texto={error} />
      <Button label="Crear escuela" variant="lime" onPress={crear} cargando={enviando} />
    </Screen>
  );
}

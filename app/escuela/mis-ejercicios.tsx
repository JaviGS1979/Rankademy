import { StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { useFocusEffect } from 'expo-router';
import { useCallback } from 'react';
import { Aviso, Button, Card, Cargando, Screen } from '@/components';
import { Tarjeta } from '@/features/biblioteca/Tarjeta';
import { useBiblioteca } from '@/features/biblioteca/useBiblioteca';
import { colors, fonts, type as t } from '@/theme';

// Los ejercicios que subí yo: públicos, de mi escuela, variantes y retirados
export default function MisEjercicios() {
  const router = useRouter();
  const { items, error, hayMas, verMas, cargandoMas, recargar } = useBiblioteca(true);
  useFocusEffect(
    useCallback(() => {
      recargar();
    }, [recargar]),
  );
  return (
    <Screen back title={'Mis\nejercicios'} subtitle="Solo tú ves que son tuyos: en la biblioteca pública son anónimos.">
      <Aviso texto={error} />
      {!items && !error && <Cargando />}
      {items?.length === 0 && (
        <Card>
          <Text style={t.h3}>Aún no has subido ninguno</Text>
          <Text style={styles.mut}>Dibuja tu primer ejercicio sobre la pista.</Text>
          <Button label="Subir ejercicio" variant="lime" small onPress={() => router.push('/escuela/subir-ejercicio')} />
        </Card>
      )}
      <View style={styles.rejilla}>
        {items?.map((e) => (
          <Tarjeta key={e.id} e={e} onPress={() => router.push({ pathname: '/escuela/ejercicio', params: { id: e.id } })} />
        ))}
      </View>
      {hayMas && <Button label="Ver más" variant="ghost" small cargando={cargandoMas} onPress={verMas} />}
    </Screen>
  );
}

const styles = StyleSheet.create({
  rejilla: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 12 },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

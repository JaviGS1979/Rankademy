import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Aviso, Button, Card, Cargando, Field, Screen } from '@/components';
import { PanelFiltros } from '@/features/biblioteca/PanelFiltros';
import { Tarjeta } from '@/features/biblioteca/Tarjeta';
import { useBiblioteca } from '@/features/biblioteca/useBiblioteca';
import { hayFiltros } from '@/lib/api';
import { colors, fonts, type as t } from '@/theme';

// Biblioteca de ejercicios: cuadrícula con búsqueda y filtros. Anónima: no dice quién subió cada uno.
export default function Biblioteca() {
  const router = useRouter();
  const { filtros, setFiltros, items, hayMas, error, verMas, cargandoMas, recargar } = useBiblioteca();
  const [filtrando, setFiltrando] = useState(false);
  const [refrescando, setRefrescando] = useState(false);

  return (
    <Screen
      title="Biblioteca"
      subtitle="Ejercicios para dar clase. Los públicos son anónimos."
      refreshing={refrescando}
      onRefresh={async () => {
        setRefrescando(true);
        await recargar();
        setRefrescando(false);
      }}
    >
      <View style={styles.fila}>
        <Button label="Subir ejercicio" variant="lime" small onPress={() => router.push('/escuela/subir-ejercicio')} style={{ flex: 1 }} />
        <Button label="Mis ejercicios" variant="ghost" small onPress={() => router.push('/escuela/mis-ejercicios')} style={{ flex: 1 }} />
      </View>

      <Field
        label="Buscar"
        placeholder="Nombre del ejercicio"
        value={filtros.texto}
        onChangeText={(texto) => setFiltros({ ...filtros, texto })}
        autoCorrect={false}
        returnKeyType="search"
      />
      <Button
        label={filtrando ? 'Ocultar filtros' : hayFiltros(filtros) ? 'Filtros (activos)' : 'Filtros'}
        variant={hayFiltros(filtros) ? 'dark' : 'ghost'}
        small
        onPress={() => setFiltrando((v) => !v)}
      />
      {filtrando && <PanelFiltros filtros={filtros} onChange={setFiltros} />}

      <Aviso texto={error} />
      {!items && !error && <Cargando />}
      {items?.length === 0 && (
        <Card>
          <Text style={t.h3}>{hayFiltros(filtros) || filtros.texto ? 'Ningún ejercicio con esos filtros' : 'Aún no hay ejercicios'}</Text>
          <Text style={styles.mut}>
            {hayFiltros(filtros) || filtros.texto ? 'Prueba con menos filtros.' : 'Sube el primero: dibújalo sobre la pista en un minuto.'}
          </Text>
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
  fila: { flexDirection: 'row', gap: 10 },
  rejilla: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 12 },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

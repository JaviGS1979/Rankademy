import { useCallback, useState } from 'react';
import { ScrollView, StyleSheet, Text, View, type NativeScrollEvent, type NativeSyntheticEvent } from 'react-native';
import { useFocusEffect, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Card, Cargando, Screen, Tag } from '@/components';
import { borrarEjercicio, retirarEjercicio } from '@/lib/api';
import { confirmar } from '@/lib/avisar';
import { mensajeError } from '@/lib/errores';
import type { DetalleEjercicio } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';
import { detalleConCache, olvidarDetalle } from './cache';
import { ESPACIOS, MATERIALES, NIVELES, OBJETIVOS, etiqueta, textoEdad } from './constantes';
import { Pista } from './Pista';

type Props = {
  id: string;
  // Dónde se abre otro ejercicio (una variante o el original)
  abrir: (id: string) => void;
  // Solo el personal de la escuela: modo pista y acciones del autor
  staff?: boolean;
};

// Detalle de un ejercicio: imágenes, pasos, material, cuántos entrenadores lo usan y variantes.
export function DetalleVista({ id, abrir, staff }: Props) {
  const router = useRouter();
  const [d, setD] = useState<DetalleEjercicio | null>(null);
  const [sinConexion, setSinConexion] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ancho, setAncho] = useState(0);
  const [pagina, setPagina] = useState(0);
  const [trabajando, setTrabajando] = useState(false);

  const cargar = useCallback(async () => {
    try {
      const r = await detalleConCache(id);
      setD(r.detalle);
      setSinConexion(r.sinConexion);
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [id]);

  useFocusEffect(
    useCallback(() => {
      setD(null);
      setPagina(0);
      cargar();
    }, [cargar]),
  );

  const alDesplazar = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    if (ancho) setPagina(Math.round(e.nativeEvent.contentOffset.x / ancho));
  };

  const accion = async (f: () => Promise<void>) => {
    setError(null);
    setTrabajando(true);
    try {
      await f();
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setTrabajando(false);
    }
  };

  if (!d) {
    return (
      <Screen back>
        <Aviso texto={error} />
        {!error && <Cargando />}
      </Screen>
    );
  }

  const edad = textoEdad(d.edad_min, d.edad_max);
  const jugadores = d.jugadores_min === d.jugadores_max ? `${d.jugadores_min} jugadores` : `${d.jugadores_min}-${d.jugadores_max} jugadores`;

  return (
    <Screen back>
      <Aviso texto={error} />
      {sinConexion && <Aviso tipo="info" texto="Sin conexión: estás viendo la última copia guardada en este dispositivo." />}

      <View onLayout={(e) => setAncho(e.nativeEvent.layout.width)} style={{ gap: 8 }}>
        {ancho > 0 && (
          <ScrollView horizontal pagingEnabled showsHorizontalScrollIndicator={false} onMomentumScrollEnd={alDesplazar} onScroll={alDesplazar} scrollEventThrottle={64}>
            {d.imagenes.map((img, i) => (
              <View key={i} style={{ width: ancho }}>
                <Pista elementos={img} etiqueta={`Imagen ${i + 1} de ${d.imagenes.length}`} />
                {d.imagenes.length > 1 && (
                  <View style={styles.contador}>
                    <Text style={styles.contadorText}>{i + 1} / {d.imagenes.length}</Text>
                  </View>
                )}
              </View>
            ))}
          </ScrollView>
        )}
        {d.imagenes.length > 1 && (
          <View style={styles.puntos} accessibilityElementsHidden>
            {d.imagenes.map((_, i) => (
              <View key={i} style={[styles.punto, i === pagina && { backgroundColor: colors.blue }]} />
            ))}
          </View>
        )}
      </View>

      <Text style={t.h2} accessibilityRole="header">{d.titulo}</Text>
      <View style={styles.fila}>
        {!!edad && <Tag texto={`${edad} años`} tipo="azul" />}
        {d.nivel && <Tag texto={etiqueta(NIVELES, d.nivel)} tipo="azul" />}
        {d.objetivo && <Tag texto={etiqueta(OBJETIVOS, d.objetivo)} tipo="azul" />}
        <Tag texto={jugadores} tipo="lima" />
        {d.espacio && <Tag texto={etiqueta(ESPACIOS, d.espacio)} tipo="azul" />}
        {d.visibilidad === 'escuela' && <Tag texto="Solo mi escuela" tipo="tinta" />}
        {d.retirado && <Tag texto="Retirado de la biblioteca" tipo="naranja" />}
      </View>

      {d.pasos.map((p, i) => (
        <View key={i} style={styles.paso}>
          <View style={styles.pasoNum}>
            <Text style={styles.pasoNumText}>{i + 1}</Text>
          </View>
          <Text style={styles.pasoText}>{p}</Text>
        </View>
      ))}

      {d.material.length > 0 && (
        <View style={styles.fila}>
          {d.material.map((m) => (
            <View key={m} style={styles.material}>
              <Text style={styles.materialText}>{etiqueta(MATERIALES, m)}</Text>
            </View>
          ))}
        </View>
      )}

      {staff && d.visibilidad === 'publica' && (
        <Text style={styles.mut}>
          {d.usado_por === 0 ? 'Aún no lo ha usado ningún entrenador' : d.usado_por === 1 ? 'Usado por 1 entrenador' : `Usado por ${d.usado_por} entrenadores`}
        </Text>
      )}

      {staff && d.original && (
        <Card>
          <Text style={styles.mut}>Es una variante de</Text>
          <Button label={d.original.titulo} variant="ghost" small onPress={() => abrir(d.original!.id)} />
        </Card>
      )}
      {staff && d.variantes.length > 0 && (
        <Card>
          <Text style={t.label} accessibilityRole="header">{d.original ? 'Otras variantes' : 'Variantes'}</Text>
          {d.variantes.map((v) => (
            <Button key={v.id} label={v.titulo} variant="ghost" small onPress={() => abrir(v.id)} />
          ))}
        </Card>
      )}

      {staff && (
        <Button
          label="Modo pista"
          variant="blue"
          onPress={() => router.push({ pathname: '/escuela/modo-pista', params: { id: d.id } })}
        />
      )}

      {staff && d.es_mio && (
        <Card>
          <Text style={t.label} accessibilityRole="header">Tu ejercicio</Text>
          <Text style={styles.mut}>
            Puedes cambiar los textos. El dibujo, los jugadores y la edad no se cambian una vez publicado, porque otros entrenadores pueden estar usándolo.
          </Text>
          <Button label="Editar textos" variant="dark" small onPress={() => router.push({ pathname: '/escuela/editar-ejercicio', params: { id: d.id } })} />
          <Button
            label={d.retirado ? 'Devolver a la biblioteca' : 'Retirar de la biblioteca'}
            variant="ghost"
            small
            cargando={trabajando}
            onPress={() =>
              d.retirado
                ? accion(async () => {
                    await retirarEjercicio(d.id, false);
                    await cargar();
                  })
                : confirmar('Retirar ejercicio', 'Dejará de aparecer en la biblioteca. Las clases que ya lo usaron lo conservan.', 'Retirar', () =>
                    accion(async () => {
                      await retirarEjercicio(d.id, true);
                      await cargar();
                    }),
                  )
            }
          />
          <Button
            label="Borrar"
            variant="ghost"
            small
            cargando={trabajando}
            onPress={() =>
              confirmar('Borrar ejercicio', 'Se borra del todo. Solo es posible si nadie lo ha usado ni tiene variantes.', 'Borrar', () =>
                accion(async () => {
                  await borrarEjercicio(d.id);
                  olvidarDetalle(d.id);
                  router.back();
                }),
              )
            }
          />
        </Card>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  contador: { position: 'absolute', top: 10, left: 10, backgroundColor: colors.ink, borderRadius: 99, paddingHorizontal: 10, paddingVertical: 3 },
  contadorText: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.white },
  puntos: { flexDirection: 'row', justifyContent: 'center', gap: 6 },
  punto: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.line },
  paso: { flexDirection: 'row', alignItems: 'center', gap: 14, minHeight: 48 },
  pasoNum: { width: 40, height: 40, borderRadius: 20, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center' },
  pasoNumText: { fontFamily: fonts.display, fontSize: 22, color: colors.lime },
  pasoText: { flex: 1, fontFamily: fonts.bodySemi, fontSize: 18, color: colors.ink },
  material: { minHeight: 36, paddingHorizontal: 14, borderRadius: 999, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.white, justifyContent: 'center' },
  materialText: { fontFamily: fonts.bodySemi, fontSize: 14, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

import { useCallback, useEffect, useRef, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Image } from 'expo-image';
import { Aviso, Button, Card, Cargando, Chip, Icon, Iniciales, Screen } from '@/components';
import {
  estadoRanking, rankingAlumnos, rankingEntrenadores, rankingEscuelas,
} from '@/lib/api';
import { miniaturas } from '@/lib/avatares';
import { compartirTexto } from '@/lib/compartir';
import { mensajeError } from '@/lib/errores';
import type {
  AmbitoRanking, EstadoRanking, FilaAlumnoRanking, FilaEntrenadorRanking, FilaEscuelaRanking,
} from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';
import { FilaRanking, Separador } from './Fila';
import { Segmentos } from './Segmentos';

type Pestana = 'alumnos' | 'entrenadores' | 'escuelas';
type AmbitoEsc = Exclude<AmbitoRanking, 'escuela' | 'pais'> | 'pais';

const PESTANAS = [
  { id: 'alumnos' as const, label: 'Alumnos' },
  { id: 'entrenadores' as const, label: 'Entrenadores' },
  { id: 'escuelas' as const, label: 'Escuelas' },
];
const AMBITOS = [
  { id: 'escuela' as const, label: 'Mi escuela' },
  { id: 'provincia' as const, label: 'Provincia' },
  { id: 'comunidad' as const, label: 'Comunidad' },
  { id: 'pais' as const, label: 'País' },
];
const AMBITOS_ESC = [
  { id: 'provincia' as const, label: 'Provincial' },
  { id: 'comunidad' as const, label: 'Autonómico' },
  { id: 'pais' as const, label: 'Nacional' },
];
const EDADES = [
  { id: 'todas', label: 'Todas', rango: null },
  { id: '8-10', label: '8-10', rango: { min: 8, max: 10 } },
  { id: '11-13', label: '11-13', rango: { min: 11, max: 13 } },
  { id: '14-17', label: '14-17', rango: { min: 14, max: 17 } },
] as const;

type Props = {
  escuelaId: string;
  // Para elegir entre varias escuelas (alumno con hijos en más de una)
  selector?: React.ReactNode;
  esDirector?: boolean;
  alAbrirPerfil: (entrenadorId: string) => void;
  alAbrirComo: () => void;
  alAbrirPanel?: () => void;
};

// Ranking de alumnos, entrenadores y escuelas. Lo usan la zona de escuela y el alumno.
export function RankingVista({ escuelaId, selector, esDirector, alAbrirPerfil, alAbrirComo, alAbrirPanel }: Props) {
  const [estado, setEstado] = useState<EstadoRanking | null>(null);
  const [pestana, setPestana] = useState<Pestana>('alumnos');
  const [ambito, setAmbito] = useState<AmbitoRanking>('escuela');
  const [ambitoEsc, setAmbitoEsc] = useState<AmbitoEsc>('provincia');
  const [edad, setEdad] = useState<(typeof EDADES)[number]['id']>('todas');
  const [alumnos, setAlumnos] = useState<FilaAlumnoRanking[] | null>(null);
  const [entrenadores, setEntrenadores] = useState<FilaEntrenadorRanking[] | null>(null);
  const [escuelas, setEscuelas] = useState<FilaEscuelaRanking[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);

  // Solo vale la respuesta de la última consulta
  const version = useRef(0);

  const ambitoActual: AmbitoRanking = pestana === 'escuelas' ? ambitoEsc : ambito;

  const cargar = useCallback(async () => {
    const mia = ++version.current;
    try {
      const est = await estadoRanking(escuelaId);
      if (mia !== version.current) return;
      setEstado(est);
      if (!est.participa) return setError(null);
      if (pestana === 'alumnos') {
        const r = await rankingAlumnos(escuelaId, ambito, EDADES.find((e) => e.id === edad)?.rango ?? null);
        if (mia === version.current) setAlumnos(r);
      } else if (pestana === 'entrenadores') {
        const r = await rankingEntrenadores(escuelaId, ambito);
        if (mia === version.current) setEntrenadores(r);
      } else {
        const r = await rankingEscuelas(escuelaId, ambitoEsc);
        if (mia === version.current) setEscuelas(r);
      }
      if (mia === version.current) setError(null);
    } catch (e) {
      if (mia === version.current) setError(mensajeError(e));
    }
  }, [escuelaId, pestana, ambito, ambitoEsc, edad]);

  // Al cambiar de pestaña, ámbito o filtro se vuelve a pedir
  useEffect(() => {
    if (pestana === 'alumnos') setAlumnos(null);
    else if (pestana === 'entrenadores') setEntrenadores(null);
    else setEscuelas(null);
    cargar();
  }, [cargar, pestana]);

  const refrescar = async () => {
    setRefrescando(true);
    await cargar();
    setRefrescando(false);
  };

  const invitar = () =>
    compartirTexto(
      'Invitar a otra escuela',
      'Te invito a Rankademy: la app de las escuelas de tenis con ranking de alumnos, entrenadores y escuelas. Cuantas más escuelas de la zona participen, más vale estar dentro.',
    );

  // Escuelas participantes en la zona elegida
  const escuelasZona = estado
    ? ambitoActual === 'provincia' ? estado.escuelas_provincia : ambitoActual === 'comunidad' ? estado.escuelas_comunidad : ambitoActual === 'pais' ? estado.escuelas_pais : 99
    : 0;
  const zonaSinNombre = !!estado && ((ambitoActual === 'provincia' && !estado.provincia.trim()) || (ambitoActual === 'comunidad' && !estado.comunidad.trim()));
  const zonaCorta = !!estado && ambitoActual !== 'escuela' && escuelasZona < estado.minimo_escuelas;

  const filas = pestana === 'alumnos' ? alumnos : pestana === 'entrenadores' ? entrenadores : escuelas;

  return (
    <Screen title="Ranking" refreshing={refrescando} onRefresh={refrescar}>
      {selector}
      <Aviso texto={error} />
      {!estado && !error && <Cargando />}

      {estado && !estado.participa && (
        <View style={styles.centro}>
          <View style={styles.trofeo}>
            <Icon name="trophy" size={44} color={colors.lime} />
          </View>
          <Text style={[t.h2, { textAlign: 'center' }]}>Tu escuela no participa en el ranking</Text>
          <Text style={styles.centroTexto}>
            Seguís con las clases, la lista y la biblioteca de ejercicios. Solo los rankings están desactivados.
          </Text>
          {esDirector ? (
            <Button label="Soy el director: activar" variant="dark" onPress={alAbrirPanel} />
          ) : (
            <Card>
              <Text style={styles.centroTexto}>¿Quieres competir? Pide al director de tu escuela que lo active.</Text>
            </Card>
          )}
        </View>
      )}

      {estado?.participa && (
        <>
          <Segmentos opciones={PESTANAS} valor={pestana} onChange={setPestana} />
          {pestana === 'escuelas' ? (
            <Segmentos opciones={AMBITOS_ESC} valor={ambitoEsc} onChange={setAmbitoEsc} compacto />
          ) : (
            <Segmentos opciones={AMBITOS} valor={ambito} onChange={setAmbito} compacto />
          )}
          {pestana === 'alumnos' && (
            <View style={styles.fila} accessibilityRole="radiogroup">
              {EDADES.map((e) => (
                <Chip key={e.id} texto={e.label} on={edad === e.id} onPress={() => setEdad(e.id)} />
              ))}
            </View>
          )}

          {zonaSinNombre ? (
            <Card>
              <Text style={t.h3}>Falta la {ambitoActual === 'provincia' ? 'provincia' : 'comunidad'} de tu escuela</Text>
              <Text style={styles.centroTexto}>
                {esDirector
                  ? 'Indícala en la pestaña Escuela para que tu escuela entre en el ranking de la zona.'
                  : 'El director de tu escuela debe indicarla para que entre en el ranking de la zona.'}
              </Text>
              {esDirector && alAbrirPanel && <Button label="Indicar la zona" variant="dark" small onPress={alAbrirPanel} />}
            </Card>
          ) : zonaCorta ? (
            <View style={styles.centro}>
              <View style={styles.podio} accessibilityElementsHidden>
                <View style={[styles.barra, { height: 56 }]} />
                <View style={[styles.barra, { height: 96 }]} />
                <View style={[styles.barra, { height: 40 }]} />
              </View>
              <Text style={[t.h2, { textAlign: 'center' }]}>Aún no hay suficientes escuelas en tu zona</Text>
              <Text style={styles.centroTexto}>
                El ranking aparece cuando varias escuelas cercanas participan. Cuantas más, más vale estar dentro.
              </Text>
              <Button label="Invitar a otra escuela" variant="lime" onPress={invitar} />
            </View>
          ) : (
            <>
              {!filas && !error && <Cargando />}
              {filas?.length === 0 && (
                <Card>
                  <Text style={t.h3}>
                    {pestana === 'escuelas' ? 'Todavía no hay escuelas con suficientes participantes' : 'Aún no hay puntos esta temporada'}
                  </Text>
                  <Text style={styles.centroTexto}>
                    {pestana === 'escuelas'
                      ? `Una escuela aparece cuando tiene un mínimo de ${estado.minimo_participantes} participantes.`
                      : 'Los puntos se suman cuando las familias confirman las asistencias.'}
                  </Text>
                </Card>
              )}
              {pestana === 'alumnos' &&
                alumnos?.map((f, i) => (
                  <View key={`${f.posicion}-${i}`} style={{ gap: 6 }}>
                    {i > 0 && f.posicion > alumnos[i - 1].posicion + 1 && f.es_mio && <Separador />}
                    <FilaRanking
                      posicion={f.posicion}
                      izquierda={<Image source={miniaturas[f.avatar] ?? miniaturas.av01} style={styles.avatar} contentFit="cover" />}
                      titulo={f.nombre}
                      subtitulo={f.escuela}
                      puntos={f.puntos}
                      mio={f.es_mio}
                    />
                  </View>
                ))}
              {pestana === 'entrenadores' &&
                entrenadores?.map((f, i) => (
                  <View key={f.entrenador_id} style={{ gap: 6 }}>
                    {i > 0 && f.posicion > entrenadores[i - 1].posicion + 1 && f.es_mio && <Separador />}
                    <FilaRanking
                      posicion={f.posicion}
                      izquierda={<Iniciales nombre={f.nombre} color={f.es_mio ? colors.ink : colors.orange} />}
                      titulo={f.nombre}
                      subtitulo={f.escuela}
                      puntos={f.puntos}
                      mio={f.es_mio}
                      onPress={() => alAbrirPerfil(f.entrenador_id)}
                    />
                  </View>
                ))}
              {pestana === 'escuelas' &&
                escuelas?.map((f, i) => (
                  <FilaRanking
                    key={`${f.posicion}-${i}`}
                    posicion={f.posicion}
                    izquierda={<Iniciales nombre={f.nombre} color={f.es_mia ? colors.ink : colors.blue} />}
                    titulo={f.nombre}
                    subtitulo={f.ciudad}
                    puntos={f.puntos}
                    unidad="media"
                    mio={f.es_mia}
                  />
                ))}
              {pestana === 'escuelas' && (escuelas?.length ?? 0) > 0 && (
                <Text style={styles.nota}>Una escuela aparece cuando tiene un mínimo de participantes.</Text>
              )}
            </>
          )}
          <Button label="Cómo se puntúa" variant="ghost" small onPress={alAbrirComo} />
        </>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  centro: { alignItems: 'stretch', gap: 14, paddingVertical: 12 },
  centroTexto: { fontFamily: fonts.body, fontSize: 15, color: colors.ink2, textAlign: 'center' },
  trofeo: { alignSelf: 'center', width: 112, height: 112, borderRadius: 56, backgroundColor: colors.ink, alignItems: 'center', justifyContent: 'center' },
  podio: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'center', gap: 10, height: 110 },
  barra: { width: 56, borderWidth: 2, borderStyle: 'dashed', borderColor: colors.ink2, borderRadius: 10 },
  avatar: { width: 44, height: 44, borderRadius: 22 },
  nota: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
});

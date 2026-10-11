import { useCallback, useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Aviso, Button, Cargando, Screen, Tag } from '@/components';
import { Cifra, Columnas, Heroe, Medidor, Seccion, Tarjeta } from '@/features/fundador/Graficos';
import { Segmentos } from '@/features/ranking/Segmentos';
import { panelFundador } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { fechaCorta, porcentaje } from '@/lib/fechas';
import type { PanelFundador } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

const PERIODOS = [
  { id: '7', label: '7 días' },
  { id: '30', label: '30 días' },
  { id: '90', label: '90 días' },
];

// Resumen del fundador: cifras agregadas de todo Rankademy. Nunca datos de personas concretas.
export default function Resumen() {
  const router = useRouter();
  const [dias, setDias] = useState('30');
  const [p, setP] = useState<PanelFundador | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);

  const cargar = useCallback(async () => {
    try {
      setP(await panelFundador(Number(dias)));
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [dias]);

  useEffect(() => {
    cargar();
  }, [cargar]);

  const c = p?.crecimiento;
  const a = p?.actividad;
  const r = p?.retencion;
  const b = p?.biblioteca;
  const k = p?.rankings;
  const nuevo = `en los últimos ${dias} días`;

  return (
    <Screen
      title="Panel del fundador"
      subtitle={p ? `Actualizado ${new Date(p.generado).toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' })}` : undefined}
      refreshing={refrescando}
      onRefresh={async () => {
        setRefrescando(true);
        await cargar();
        setRefrescando(false);
      }}
    >
      <Segmentos opciones={PERIODOS} valor={dias} onChange={(v) => { setP(null); setDias(v); }} />
      <Aviso texto={error} />
      {!p && !error && <Cargando />}

      {c && a && r && b && k && (
        <>
          <Heroe etiqueta="Alumnos" valor={c.alumnos} detalle={`${c.alumnos_nuevos} nuevos ${nuevo} · ${c.alumnos_mini} son Mini`} />

          <Seccion titulo="Crecimiento">
            <View style={styles.rejilla}>
              <Cifra etiqueta="Escuelas" valor={c.escuelas} detalle={`+${c.escuelas_nuevas} ${nuevo}`} />
              <Cifra etiqueta="Personas con cuenta" valor={c.personas} detalle={`+${c.personas_nuevas} ${nuevo}`} />
              <Cifra etiqueta="Directores" valor={c.directores} />
              <Cifra etiqueta="Entrenadores" valor={c.entrenadores} />
              <Cifra etiqueta="Familias" valor={c.familias} />
              <Cifra etiqueta="Solicitudes pendientes" valor={c.solicitudes_pendientes} detalle="esperando al director" />
            </View>
            <Columnas titulo="Cuentas nuevas por semana" unidad="cuentas" datos={c.por_semana.map((x) => ({ semana: x.semana, valor: x.personas }))} />
            <Columnas titulo="Alumnos nuevos por semana" unidad="alumnos" datos={c.por_semana.map((x) => ({ semana: x.semana, valor: x.alumnos }))} />
          </Seccion>

          <Seccion titulo="Actividad">
            <View style={styles.rejilla}>
              <Cifra etiqueta="Clases con lista" valor={a.clases_con_lista} detalle={nuevo} />
              <Cifra etiqueta="Clases canceladas" valor={a.clases_canceladas} detalle={nuevo} />
              <Cifra etiqueta="Entrenadores que pasan lista" valor={a.entrenadores_que_pasan_lista} />
              <Cifra etiqueta="Familias que confirman" valor={a.familias_que_confirman} />
            </View>
            <Tarjeta>
              <Medidor
                etiqueta="Asistencias confirmadas por las familias"
                parte={a.asistencias_confirmadas}
                total={a.asistencias_marcadas}
              />
              <Text style={styles.nota}>
                Es la señal más importante del producto: solo las asistencias confirmadas dan XP y cuentan en los rankings.
              </Text>
            </Tarjeta>
            <Columnas titulo="Clases con lista por semana" unidad="clases" datos={a.por_semana.map((x) => ({ semana: x.semana, valor: x.clases }))} />
            <Columnas titulo="Asistencias confirmadas por semana" unidad="asistencias" datos={a.por_semana.map((x) => ({ semana: x.semana, valor: x.confirmadas }))} />
          </Seccion>

          <Seccion titulo="Retención">
            <Tarjeta>
              <Medidor
                etiqueta="Alumnos con más de 30 días que siguen yendo"
                parte={r.alumnos_veteranos_activos_30d}
                total={r.alumnos_veteranos}
                detalle={r.alumnos_veteranos === 0 ? 'Aún no hay alumnos con 30 días en la app' : `${r.alumnos_veteranos_activos_30d} de ${r.alumnos_veteranos} con alguna asistencia en 30 días`}
              />
              <Medidor
                etiqueta="Escuelas que han pasado lista en 14 días"
                parte={r.escuelas_activas_14d}
                total={c.escuelas}
              />
              <Medidor
                etiqueta="Entrenadores que han pasado lista en 14 días"
                parte={r.entrenadores_activos_14d}
                total={c.entrenadores}
              />
            </Tarjeta>
            <View style={styles.rejilla}>
              <Cifra etiqueta="Bajas" valor={r.bajas} detalle="en total" />
            </View>
          </Seccion>

          <Seccion titulo="Biblioteca">
            <View style={styles.rejilla}>
              <Cifra etiqueta="Ejercicios públicos" valor={b.publicos} detalle={`${b.variantes} variantes`} />
              <Cifra etiqueta="Solo de una escuela" valor={b.privados} />
              <Cifra etiqueta="Subidos" valor={b.nuevos} detalle={nuevo} />
              <Cifra etiqueta="Entrenadores que suben" valor={b.autores} />
              <Cifra etiqueta="Usos en clase" valor={b.usos_periodo} detalle={nuevo} />
              <Cifra
                etiqueta="Clases con ejercicios"
                valor={porcentaje(b.clases_con_ejercicios, a.clases_con_lista) + ' %'}
                detalle={`${b.clases_con_ejercicios} de ${a.clases_con_lista} con lista`}
              />
            </View>
            {b.mas_usados.length > 0 && (
              <Tarjeta>
                <Text style={styles.titulo}>Los más usados</Text>
                {b.mas_usados.map((e, i) => (
                  <View key={i} style={styles.fila}>
                    <Text style={[styles.titulo, { flex: 1 }]} numberOfLines={1}>{e.titulo}</Text>
                    <Text style={styles.nota}>{e.usado_por === 1 ? '1 entrenador' : `${e.usado_por} entrenadores`}</Text>
                  </View>
                ))}
              </Tarjeta>
            )}
          </Seccion>

          <Seccion titulo="Rankings">
            <View style={styles.rejilla}>
              <Cifra etiqueta="Escuelas que participan" valor={k.escuelas_participan} detalle={k.escuelas_sin_provincia > 0 ? `${k.escuelas_sin_provincia} sin provincia` : 'todas con provincia'} />
              <Cifra etiqueta="Alumnos que compiten" valor={k.alumnos_compiten} detalle={`${k.alumnos_no_quieren} prefieren no salir`} />
            </View>
            <Tarjeta>
              <Text style={styles.titulo}>Zonas (hacen falta {k.minimo_escuelas} escuelas)</Text>
              {k.provincias.length === 0 && <Text style={styles.nota}>Ninguna escuela ha indicado su provincia todavía.</Text>}
              {k.provincias.map((z) => (
                <View key={z.provincia} style={styles.fila}>
                  <Text style={[styles.titulo, { flex: 1 }]}>{z.provincia}</Text>
                  <Text style={styles.nota}>{z.escuelas} {z.escuelas === 1 ? 'escuela' : 'escuelas'}</Text>
                  <Tag texto={z.con_ranking ? 'Con ranking' : `Faltan ${k.minimo_escuelas - z.escuelas}`} tipo={z.con_ranking ? 'lima' : 'naranja'} />
                </View>
              ))}
              <Text style={styles.nota}>Temporada desde el {fechaCorta(k.temporada_desde)}.</Text>
            </Tarjeta>
          </Seccion>
        </>
      )}

      <Button label="Volver a la app" variant="ghost" onPress={() => router.replace('/inicio')} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  rejilla: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 12 },
  nota: { fontFamily: fonts.body, fontSize: 13, color: colors.ink2 },
  titulo: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.ink },
  fila: { flexDirection: 'row', alignItems: 'center', gap: 10, minHeight: 36 },
});

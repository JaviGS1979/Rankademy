import { useState, type ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import * as Haptics from 'expo-haptics';
import { Button } from '@/components';
import { fechaCorta } from '@/lib/fechas';
import { formato } from '@/features/ranking/Fila';
import { colors, fonts, type as t } from '@/theme';

// Marcas del gráfico: una sola tonalidad. La seleccionada en el azul de la marca; el resto, un paso más claro
// (3,9:1 sobre blanco, por encima del mínimo de 3:1 para marcas).
const AZUL = colors.blue;
const AZUL_SUAVE = '#5B78F5';

// ---------- Cifra: valor + etiqueta (+ detalle) ----------
export function Cifra({ etiqueta, valor, detalle, ancho = '48%' }: { etiqueta: string; valor: number | string; detalle?: string; ancho?: number | string }) {
  return (
    <View style={[styles.cifra, { width: ancho as never }]} accessible accessibilityLabel={`${etiqueta}: ${typeof valor === 'number' ? formato(valor) : valor}${detalle ? `, ${detalle}` : ''}`}>
      <Text style={styles.cifraEt}>{etiqueta}</Text>
      <Text style={styles.cifraValor}>{typeof valor === 'number' ? formato(valor) : valor}</Text>
      {!!detalle && <Text style={styles.cifraDet}>{detalle}</Text>}
    </View>
  );
}

// La cifra con la que abre el panel (una sola por vista)
export function Heroe({ etiqueta, valor, detalle }: { etiqueta: string; valor: number; detalle?: string }) {
  return (
    <View style={styles.heroe} accessible accessibilityLabel={`${etiqueta}: ${formato(valor)}${detalle ? `, ${detalle}` : ''}`}>
      <Text style={styles.heroeEt}>{etiqueta}</Text>
      <Text style={styles.heroeValor}>{formato(valor)}</Text>
      {!!detalle && <Text style={styles.heroeDet}>{detalle}</Text>}
    </View>
  );
}

export function Seccion({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <View style={{ gap: 12 }}>
      <Text style={t.h2} accessibilityRole="header">{titulo}</Text>
      {children}
    </View>
  );
}

export function Tarjeta({ children }: { children: ReactNode }) {
  return <View style={styles.tarjeta}>{children}</View>;
}

// ---------- Medidor: una proporción (el relleno en el azul, la pista en un paso más claro del mismo azul) ----------
export function Medidor({ etiqueta, parte, total, detalle }: { etiqueta: string; parte: number; total: number; detalle?: string }) {
  const pct = total > 0 ? Math.min(100, Math.round((100 * parte) / total)) : 0;
  return (
    <View style={{ gap: 6 }} accessible accessibilityLabel={`${etiqueta}: ${pct} %, ${parte} de ${total}`}>
      <View style={styles.medidorFila}>
        <Text style={styles.medidorEt}>{etiqueta}</Text>
        <Text style={styles.medidorPct}>{total > 0 ? `${pct} %` : 'Sin datos'}</Text>
      </View>
      <View style={styles.pista}>
        <View style={[styles.relleno, { width: `${pct}%` }]} />
      </View>
      <Text style={styles.cifraDet}>{detalle ?? `${formato(parte)} de ${formato(total)}`}</Text>
    </View>
  );
}

// ---------- Columnas por semana (una serie: sin leyenda, el título dice qué es) ----------
type Punto = { semana: string; valor: number };
const ALTO = 112;

export function Columnas({ titulo, unidad, datos }: { titulo: string; unidad: string; datos: Punto[] }) {
  const [sel, setSel] = useState<number | null>(null);
  const [tabla, setTabla] = useState(false);
  const max = Math.max(1, ...datos.map((d) => d.valor));
  const activo = sel ?? datos.length - 1;
  const total = datos.reduce((a, d) => a + d.valor, 0);
  const lectura = datos[activo]
    ? `Semana del ${fechaCorta(datos[activo].semana)}${activo === datos.length - 1 ? ' (en curso)' : ''}: ${formato(datos[activo].valor)} ${unidad}`
    : '';

  return (
    <Tarjeta>
      <Text style={styles.graficoTitulo} accessibilityRole="header">{titulo}</Text>
      {total === 0 ? (
        <Text style={styles.cifraDet}>Todavía no hay datos en las últimas 12 semanas.</Text>
      ) : (
        <>
          <Text style={styles.lectura} accessibilityLiveRegion="polite">{lectura}</Text>
          <View style={styles.grafico}>
            <View style={styles.ejeY}>
              <Text style={styles.tick}>{formato(max)}</Text>
              <Text style={styles.tick}>0</Text>
            </View>
            <View style={styles.area}>
              <View style={[styles.rejilla, { top: 0 }]} />
              <View style={[styles.rejilla, { bottom: 0 }]} />
              <View style={styles.columnas}>
                {datos.map((d, i) => (
                  <Pressable
                    key={d.semana}
                    accessibilityRole="button"
                    accessibilityLabel={`Semana del ${fechaCorta(d.semana)}: ${d.valor} ${unidad}`}
                    onPress={() => {
                      Haptics.selectionAsync().catch(() => {});
                      setSel(i);
                    }}
                    style={styles.hueco}
                  >
                    <View
                      style={[
                        styles.columna,
                        { height: Math.max(d.valor > 0 ? 3 : 0, (d.valor / max) * ALTO) },
                        { backgroundColor: i === activo ? AZUL : AZUL_SUAVE },
                      ]}
                    />
                  </Pressable>
                ))}
              </View>
            </View>
          </View>
          <View style={styles.ejeX}>
            <Text style={styles.tick}>{fechaCorta(datos[0].semana)}</Text>
            <Text style={styles.tick}>{fechaCorta(datos[datos.length - 1].semana)}</Text>
          </View>
          <Button label={tabla ? 'Ocultar tabla' : 'Ver tabla'} variant="ghost" small onPress={() => setTabla((v) => !v)} />
          {tabla &&
            datos.map((d) => (
              <View key={d.semana} style={styles.filaTabla}>
                <Text style={styles.cifraDet}>Semana del {fechaCorta(d.semana)}</Text>
                <Text style={styles.tablaValor}>{formato(d.valor)}</Text>
              </View>
            ))}
        </>
      )}
    </Tarjeta>
  );
}

const styles = StyleSheet.create({
  cifra: { backgroundColor: colors.card, borderRadius: 18, borderWidth: 1, borderColor: colors.line, padding: 14, gap: 2 },
  cifraEt: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.ink2 },
  cifraValor: { fontFamily: fonts.display, fontSize: 38, color: colors.ink },
  cifraDet: { fontFamily: fonts.body, fontSize: 13, color: colors.ink2 },
  heroe: { backgroundColor: colors.ink, borderRadius: 22, padding: 20, gap: 2 },
  heroeEt: { fontFamily: fonts.bodyBold, fontSize: 13, letterSpacing: 0.96, textTransform: 'uppercase', color: colors.muted },
  heroeValor: { fontFamily: fonts.display, fontSize: 72, lineHeight: 74, color: colors.lime },
  heroeDet: { fontFamily: fonts.body, fontSize: 15, color: colors.muted },
  tarjeta: { backgroundColor: colors.card, borderRadius: 20, borderWidth: 1, borderColor: colors.line, padding: 16, gap: 12 },
  medidorFila: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline' },
  medidorEt: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.ink, flex: 1 },
  medidorPct: { fontFamily: fonts.display, fontSize: 26, color: colors.ink },
  pista: { height: 10, borderRadius: 5, backgroundColor: colors.blueLight, overflow: 'hidden' },
  relleno: { height: 10, borderRadius: 5, backgroundColor: AZUL },
  graficoTitulo: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  lectura: { fontFamily: fonts.bodySemi, fontSize: 14, color: colors.ink },
  grafico: { flexDirection: 'row', gap: 8, height: ALTO },
  ejeY: { width: 34, justifyContent: 'space-between', alignItems: 'flex-end' },
  tick: { fontFamily: fonts.body, fontSize: 11, color: colors.ink2 },
  area: { flex: 1, height: ALTO },
  rejilla: { position: 'absolute', left: 0, right: 0, height: 1, backgroundColor: colors.line },
  columnas: { flex: 1, flexDirection: 'row', alignItems: 'flex-end' },
  hueco: { flex: 1, height: ALTO, alignItems: 'center', justifyContent: 'flex-end', minWidth: 20 },
  // Hasta 24 px de ancho, con el extremo superior redondeado y la base recta
  columna: { width: '70%', maxWidth: 24, borderTopLeftRadius: 4, borderTopRightRadius: 4 },
  ejeX: { flexDirection: 'row', justifyContent: 'space-between', paddingLeft: 42 },
  filaTabla: { flexDirection: 'row', justifyContent: 'space-between', borderTopWidth: 1, borderTopColor: colors.line, paddingTop: 6 },
  tablaValor: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
});

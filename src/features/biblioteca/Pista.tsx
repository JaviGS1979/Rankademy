import { StyleSheet, View, type StyleProp, type ViewStyle } from 'react-native';
import Svg, { Circle, G, Path, Polygon, Rect } from 'react-native-svg';
import type { Elemento } from '@/lib/tipos';
import { colors } from '@/theme';

type Props = {
  elementos: Elemento[];
  // Trazos más gruesos para las miniaturas
  miniatura?: boolean;
  // Punto de salida de un trayecto a medio dibujar (editor)
  pendiente?: [number, number] | null;
  style?: StyleProp<ViewStyle>;
  etiqueta?: string;
};

export const PISTA_W = 240;
export const PISTA_H = 140;
const CONO = '#FF8A3D';

// Flecha al final de un trayecto: triángulo orientado según la dirección de llegada
function flecha(desde: [number, number], a: [number, number], k: number) {
  const dx = a[0] - desde[0];
  const dy = a[1] - desde[1];
  const l = Math.hypot(dx, dy) || 1;
  const ux = dx / l;
  const uy = dy / l;
  const bx = a[0] - ux * 9 * k;
  const by = a[1] - uy * 9 * k;
  const nx = -uy * 4.5 * k;
  const ny = ux * 4.5 * k;
  return `${a[0]},${a[1]} ${bx + nx},${by + ny} ${bx - nx},${by - ny}`;
}

// La pista de tenis con el dibujo encima. Ocupa todo el ancho y mantiene la proporción 240 × 140.
export function Pista({ elementos, miniatura, pendiente, style, etiqueta }: Props) {
  const k = miniatura ? 1.25 : 1;
  const trazo = miniatura ? 4.5 : 3;
  return (
    <View
      style={[styles.pista, style]}
      accessibilityRole="image"
      accessibilityLabel={etiqueta ?? 'Dibujo del ejercicio sobre la pista'}
    >
      <Svg width="100%" height="100%" viewBox={`0 0 ${PISTA_W} ${PISTA_H}`}>
        <G fill="none" stroke="#FFFFFF" strokeWidth={1.6}>
          <Rect x={12} y={10} width={216} height={120} />
          <Path d="M12 24h216M12 116h216M60 24v92M180 24v92M60 70h120" />
          <Path d="M120 6v128" strokeWidth={2.4} />
        </G>
        {elementos.map((el, i) => {
          if (el.t === 'trayecto') {
            const carrera = el.tipo === 'carrera';
            const color = carrera ? colors.white : colors.lime;
            const d = el.c
              ? `M${el.de[0]} ${el.de[1]} Q${el.c[0]} ${el.c[1]} ${el.a[0]} ${el.a[1]}`
              : `M${el.de[0]} ${el.de[1]} L${el.a[0]} ${el.a[1]}`;
            return (
              <G key={i}>
                <Path d={d} stroke={color} strokeWidth={trazo} fill="none" strokeDasharray={`${trazo * 2} ${trazo * 1.6}`} strokeLinecap="round" />
                <Polygon points={flecha(el.c ?? el.de, el.a, k)} fill={color} />
              </G>
            );
          }
          if (el.t === 'jugador') return <Circle key={i} cx={el.x} cy={el.y} r={7 * k} fill={colors.lime} />;
          if (el.t === 'pelota') return <Circle key={i} cx={el.x} cy={el.y} r={5.5 * k} fill={colors.white} />;
          const r = 6 * k;
          return <Polygon key={i} points={`${el.x},${el.y - r} ${el.x + r},${el.y + r * 0.8} ${el.x - r},${el.y + r * 0.8}`} fill={CONO} />;
        })}
        {pendiente && <Circle cx={pendiente[0]} cy={pendiente[1]} r={9} fill="none" stroke={colors.lime} strokeWidth={2} />}
      </Svg>
    </View>
  );
}

const styles = StyleSheet.create({
  pista: { width: '100%', aspectRatio: PISTA_W / PISTA_H, backgroundColor: colors.blue, borderRadius: 14, overflow: 'hidden' },
});

import { StyleSheet, Text, View } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { Image } from 'expo-image';
import Animated, { Easing, useAnimatedStyle, useReducedMotion, useSharedValue, withDelay, withTiming } from 'react-native-reanimated';
import { useEffect } from 'react';
import { Button, Icon, Screen } from '@/components';
import { BarraXp } from '@/components/Alumno';
import { miniaturas } from '@/lib/avatares';
import type { ResultadoConfirmacion } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

// Resumen tras confirmar la asistencia: XP ganado, racha, subida de nivel y avatares nuevos.
export default function Resumen() {
  const router = useRouter();
  const { datos, nombre } = useLocalSearchParams<{ datos?: string; nombre?: string }>();
  let r: ResultadoConfirmacion | null = null;
  try {
    r = datos ? (JSON.parse(datos) as ResultadoConfirmacion) : null;
  } catch {}

  const reducido = useReducedMotion();
  const v = useSharedValue(reducido ? 1 : 0);
  useEffect(() => {
    if (!reducido) v.value = withDelay(150, withTiming(1, { duration: 600, easing: Easing.out(Easing.cubic) }));
  }, [reducido, v]);
  const entrada = useAnimatedStyle(() => ({ opacity: v.value, transform: [{ translateY: (1 - v.value) * 24 }] }));

  const seguir = () => router.replace('/alumno');
  if (!r) {
    return (
      <Screen dark title="Listo">
        <Button label="Seguir" variant="lime" onPress={seguir} />
      </Screen>
    );
  }
  const subeNivel = r.nivel_despues > r.nivel_antes;

  return (
    <Screen dark>
      <Animated.View style={[styles.centro, entrada]}>
        <View style={styles.sello}>
          <Icon name="check" size={18} color={colors.ink} strokeWidth={3} />
          <Text style={styles.selloText}>Asistencia confirmada</Text>
        </View>
        <Text style={styles.titulo} accessibilityRole="header">{`¡Buen\ntrabajo, ${nombre ?? ''}!`}</Text>

        <View style={styles.xp}>
          <Text style={styles.xpNum}>+{r.xp_ganados}</Text>
          <Text style={styles.xpEtiqueta}>XP ganados</Text>
        </View>

        <View style={styles.fila}>
          <Icon name="flame" size={28} color="#FF8A4C" fill="#FF8A4C" />
          <View>
            <Text style={styles.dato}>Racha: {r.racha} {r.racha === 1 ? 'semana' : 'semanas'}</Text>
            <Text style={styles.mut}>{r.racha > 1 ? '¡Una semana más!' : '¡Empieza tu racha!'}</Text>
          </View>
        </View>

        {subeNivel && (
          <View style={styles.nivel}>
            <Icon name="star" size={28} color={colors.ink} />
            <View>
              <Text style={[styles.dato, { color: colors.ink }]}>¡Subes de nivel!</Text>
              <Text style={[styles.mut, { color: colors.ink }]}>{r.nivel_antes} → {r.nivel_despues}</Text>
            </View>
          </View>
        )}

        {r.avatares_nuevos.length > 0 && (
          <View style={styles.fila}>
            <View style={styles.nuevos}>
              {r.avatares_nuevos.slice(0, 3).map((a) => (
                <Image key={a} source={miniaturas[a]} style={styles.mini} contentFit="cover" />
              ))}
            </View>
            <Text style={styles.dato}>
              {r.avatares_nuevos.length === 1 ? 'Avatar nuevo desbloqueado' : `${r.avatares_nuevos.length} avatares nuevos`}
            </Text>
          </View>
        )}

        <View style={{ gap: 6 }}>
          <Text style={styles.mut}>Nivel {r.nivel_despues}: {r.xp_total % 250} / 250 XP</Text>
          <BarraXp valor={(r.xp_total % 250) / 250} />
        </View>
      </Animated.View>
      <Button label="Seguir" variant="lime" onPress={seguir} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  centro: { flex: 1, gap: 20, justifyContent: 'center' },
  sello: { flexDirection: 'row', alignItems: 'center', gap: 6, alignSelf: 'flex-start', backgroundColor: colors.lime, borderRadius: 999, paddingHorizontal: 12, height: 30 },
  selloText: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.ink },
  titulo: { fontFamily: fonts.display, fontSize: 46, lineHeight: 44, color: colors.white, textTransform: 'uppercase' },
  xp: { flexDirection: 'row', alignItems: 'baseline', gap: 10 },
  xpNum: { fontFamily: fonts.display, fontSize: 96, lineHeight: 96, color: colors.lime },
  xpEtiqueta: { fontFamily: fonts.display, fontSize: 28, color: colors.white, textTransform: 'uppercase' },
  fila: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  dato: { fontFamily: fonts.bodyBold, fontSize: 17, color: colors.white },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.muted },
  nivel: { flexDirection: 'row', alignItems: 'center', gap: 12, backgroundColor: colors.lime, borderRadius: 18, padding: 14 },
  nuevos: { flexDirection: 'row' },
  mini: { width: 44, height: 44, borderRadius: 22, borderWidth: 2, borderColor: colors.lime, marginRight: -10 },
});

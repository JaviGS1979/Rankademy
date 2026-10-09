import { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import Animated, {
  Easing,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
  withDelay,
  withSequence,
  withTiming,
} from 'react-native-reanimated';
import { Button, Logo, Screen, Wordmark } from '@/components';
import { colors, fonts } from '@/theme';

// Ritmo tomado de las animaciones del diseño (Main.html), ejecutado una sola vez.
const out = Easing.out(Easing.cubic);

function useEntrance(delay: number, reduced: boolean) {
  const v = useSharedValue(reduced ? 1 : 0);
  useEffect(() => {
    if (!reduced) v.value = withDelay(delay, withTiming(1, { duration: 450, easing: out }));
  }, [delay, reduced, v]);
  return v;
}

function Bar({ rank, height, color, delay, reduced, winner }: {
  rank: number; height: number; color: string; delay: number; reduced: boolean; winner?: boolean;
}) {
  const grow = useSharedValue(reduced ? 1 : 0);
  const pop = useSharedValue(reduced ? 1 : 0);
  useEffect(() => {
    if (reduced) return;
    grow.value = withDelay(delay, withTiming(1, { duration: 700, easing: out }));
    pop.value = withDelay(
      delay + 500,
      withSequence(withTiming(1.15, { duration: 200 }), withTiming(1, { duration: 150 })),
    );
  }, [delay, reduced, grow, pop]);
  const barStyle = useAnimatedStyle(() => ({ height: height * grow.value }));
  const numStyle = useAnimatedStyle(() => ({
    opacity: pop.value > 0 ? 1 : 0,
    transform: [{ scale: pop.value }],
  }));
  return (
    <View style={styles.barCol}>
      <Animated.Text
        style={[styles.rank, { fontSize: winner ? 40 : 32, color: winner ? colors.lime : colors.muted }, numStyle]}
      >
        {rank}
      </Animated.Text>
      <Animated.View style={[{ width: '100%', backgroundColor: color, borderTopLeftRadius: 16, borderTopRightRadius: 16 }, barStyle]} />
    </View>
  );
}

export default function Arranque() {
  const router = useRouter();
  const reduced = useReducedMotion();
  const logo = useEntrance(0, reduced);
  const tagline = useEntrance(500, reduced);
  const cta1 = useEntrance(900, reduced);
  const cta2 = useEntrance(1000, reduced);

  const useFade = (v: typeof logo, dy = 16) =>
    useAnimatedStyle(() => ({ opacity: v.value, transform: [{ translateY: (1 - v.value) * dy }] }));
  const logoStyle = useAnimatedStyle(() => ({ opacity: logo.value, transform: [{ scale: 0.4 + 0.6 * logo.value }] }));
  const taglineStyle = useFade(tagline);
  const cta1Style = useFade(cta1);
  const cta2Style = useFade(cta2);

  return (
    <Screen dark scroll={false}>
      <View style={styles.top}>
        <Animated.View style={logoStyle}>
          <Logo />
        </Animated.View>
        <Wordmark />
        <Animated.Text style={[styles.tagline, taglineStyle]}>
          El ranking de las escuelas de tenis.
        </Animated.Text>
      </View>

      <View style={styles.podium} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
        <Bar rank={2} height={110} color={colors.blue} delay={300} reduced={reduced} />
        <Bar rank={1} height={170} color={colors.lime} delay={500} reduced={reduced} winner />
        <Bar rank={3} height={70} color={colors.white} delay={150} reduced={reduced} />
      </View>

      <View style={styles.actions}>
        <Animated.View style={cta1Style}>
          <Button label="Empezar" variant="lime" onPress={() => router.push('/soy')} />
        </Animated.View>
        <Animated.View style={cta2Style}>
          <Button label="Ya tengo cuenta" variant="ghostLight" onPress={() => router.push('/entrar')} />
        </Animated.View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  top: { gap: 18, alignItems: 'flex-start', paddingTop: 36 },
  tagline: { fontFamily: fonts.bodySemi, fontSize: 20, color: colors.white, maxWidth: 280 },
  podium: { flex: 1, flexDirection: 'row', alignItems: 'flex-end', gap: 10, minHeight: 200 },
  barCol: { flex: 1, alignItems: 'center', gap: 6 },
  rank: { fontFamily: fonts.display },
  actions: { gap: 12 },
});

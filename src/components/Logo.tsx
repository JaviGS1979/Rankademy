import Svg, { Circle, Path } from 'react-native-svg';
import { Text, View } from 'react-native';
import { colors, display } from '@/theme';

export function Logo({ size = 64 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 64 64" accessibilityLabel="Logotipo Rankademy">
      <Circle cx="32" cy="32" r="30" fill={colors.lime} />
      <Path
        d="M10 14c12 6 18 14 18 28M54 50c-12-6-18-14-18-28"
        fill="none"
        stroke={colors.ink}
        strokeWidth={4}
        strokeLinecap="round"
      />
    </Svg>
  );
}

// "Rank" en blanco y "ademy" en lima, siempre junto y en una línea
export function Wordmark({ size = 72 }: { size?: number }) {
  return (
    <View style={{ flexDirection: 'row' }} accessibilityRole="header" accessibilityLabel="Rankademy">
      <Text style={[display(size), { color: colors.white }]} numberOfLines={1}>
        Rank
      </Text>
      <Text style={[display(size), { color: colors.lime }]} numberOfLines={1}>
        ademy
      </Text>
    </View>
  );
}

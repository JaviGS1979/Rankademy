import { View } from 'react-native';
import Svg, { Circle, Path, Rect } from 'react-native-svg';

// Iconos del diseño (viewBox 24x24, trazo 2, extremos redondeados)
const icons = {
  back: <Path d="M15 5l-7 7 7 7" />,
  next: <Path d="M9 5l7 7-7 7" />,
  check: <Path d="M4 12l5 5L20 6" />,
  school: (
    <>
      <Rect x="5" y="4" width="14" height="17" rx="2" />
      <Path d="M9 4h6v3H9zM9 12h6M9 16h4" />
    </>
  ),
  coach: (
    <>
      <Circle cx="9" cy="8" r="3.5" />
      <Path d="M2.5 20c0-3.5 3-6 6.5-6s6.5 2.5 6.5 6" />
      <Path d="M16 4.5a3.5 3.5 0 010 7M18 14c2.2.6 3.5 2.6 3.5 6" />
    </>
  ),
  share: (
    <>
      <Path d="M12 3v12M7 8l5-5 5 5" />
      <Path d="M5 13v6a2 2 0 002 2h10a2 2 0 002-2v-6" />
    </>
  ),
  flame: <Path d="M12 3c1 4 5 5.500 5 11a5 5 0 01-10 0c0-2 1-3.500 2-4.500.3 1.500 1 2 2 2.200C10.500 8.500 11 5.500 12 3z" />,
  star: <Path d="M12 3l2.700 5.600 6.100.9-4.400 4.300 1 6.100L12 17l-5.400 2.900 1-6.100L3.200 9.500l6.100-.9z" />,
  user: (
    <>
      <Circle cx="12" cy="8" r="4" />
      <Path d="M4 21c0-4 3.600-7 8-7s8 3 8 7" />
    </>
  ),
  calendar: (
    <>
      <Rect x="3" y="5" width="18" height="16" rx="3" />
      <Path d="M3 10h18M8 3v4M16 3v4" />
    </>
  ),
  play: <Path d="M7 4l13 8-13 8z" />,
  lock: (
    <>
      <Rect x="5" y="11" width="14" height="10" rx="2" />
      <Path d="M8 11V8a4 4 0 018 0v3" />
    </>
  ),
  chart: <Path d="M4 20V10M10 20V4M16 20v-7M22 20H2" />,
  trophy: (
    <>
      <Path d="M8 4h8v5a4 4 0 01-8 0zM8 6H4v1a4 4 0 004 4M16 6h4v1a4 4 0 01-4 4" />
      <Path d="M12 13v4M8 21h8M10 17h4" />
    </>
  ),
  list: <Path d="M8 6h13M8 12h13M8 18h13M3.500 6h.01M3.500 12h.01M3.500 18h.01" />,
  down: <Path d="M6 9l6 6 6-6" />,
  plus: <Path d="M12 5v14M5 12h14" />,
  close: <Path d="M6 6l12 12M18 6L6 18" />,
  clock: (
    <>
      <Circle cx="12" cy="12" r="9" />
      <Path d="M12 7v5l3 2" />
    </>
  ),
  home: (
    <>
      <Path d="M3 11l9-8 9 8" />
      <Path d="M5 10v10h5v-6h4v6h5V10" />
    </>
  ),
} as const;

export type IconName = keyof typeof icons;

type Props = { name: IconName; size?: number; color?: string; strokeWidth?: number; fill?: string };

export function Icon({ name, size = 24, color = '#0F1D2E', strokeWidth = 2, fill = 'none' }: Props) {
  // Decorativo: oculto al lector de pantalla. Las props de accesibilidad van
  // en un View porque Svg las pasa tal cual al DOM en web (aviso de React).
  return (
    <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <Svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill={fill}
        stroke={color}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        {icons[name]}
      </Svg>
    </View>
  );
}

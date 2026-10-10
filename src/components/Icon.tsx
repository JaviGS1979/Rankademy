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

type Props = { name: IconName; size?: number; color?: string; strokeWidth?: number };

export function Icon({ name, size = 24, color = '#0F1D2E', strokeWidth = 2 }: Props) {
  // Decorativo: oculto al lector de pantalla. Las props de accesibilidad van
  // en un View porque Svg las pasa tal cual al DOM en web (aviso de React).
  return (
    <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      <Svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
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

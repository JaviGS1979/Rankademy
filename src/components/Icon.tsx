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
  return (
    <Svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke={color}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      {icons[name]}
    </Svg>
  );
}

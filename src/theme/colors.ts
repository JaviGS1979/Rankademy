// Tokens de color de design/assets/rankademy.css
export const colors = {
  ink: '#0F1D2E',
  ink2: '#46566B',
  muted: '#B6C2D0',
  bg: '#F3F5F7',
  card: '#FFFFFF',
  line: '#DCE2E9',
  lime: '#C8E63A',
  blue: '#2446F0',
  blueLight: '#E4E9FF',
  blueDark: '#1A2FB3',
  orange: '#C2410C',
  orangeLight: '#FFE9DD',
  orangeDark: '#9A330A',
  miniBg: '#F6FAD9',
  white: '#FFFFFF',
} as const;

export type ColorName = keyof typeof colors;

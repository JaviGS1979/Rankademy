import type { TextStyle } from 'react-native';

export const fonts = {
  display: 'BarlowCondensed_800ExtraBold',
  displayBold: 'BarlowCondensed_700Bold',
  body: 'Figtree_400Regular',
  bodySemi: 'Figtree_600SemiBold',
  bodyBold: 'Figtree_700Bold',
  bodyHeavy: 'Figtree_800ExtraBold',
} as const;

// Equivalentes a .h1 .h2 .h3 de rankademy.css (titulares en mayúsculas)
export const display = (size: number): TextStyle => ({
  fontFamily: fonts.display,
  fontSize: size,
  lineHeight: Math.round(size * 0.95),
  letterSpacing: size * 0.01,
  textTransform: 'uppercase',
});

export const type = {
  h1: display(42),
  h2: display(30),
  h3: display(22),
  body: { fontFamily: fonts.body, fontSize: 16, lineHeight: 22 } as TextStyle,
  label: {
    fontFamily: fonts.bodyBold,
    fontSize: 12,
    letterSpacing: 0.96,
    textTransform: 'uppercase',
  } as TextStyle,
};

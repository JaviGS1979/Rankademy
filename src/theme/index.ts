export { colors } from './colors';
export type { ColorName } from './colors';
export { fonts, display, type } from './typography';

export const radius = { chip: 999, card: 20, btn: 16, field: 14, hero: 24 } as const;
export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24 } as const;
// Objetivo táctil mínimo (44 pt) y alto de botón principal (56 pt)
export const touch = { min: 44, btn: 56 } as const;

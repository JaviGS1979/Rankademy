// Opciones de la biblioteca (los mismos valores que acepta la base de datos)
export const EDADES = [
  { id: '3-7', min: 3, max: 7 },
  { id: '8-13', min: 8, max: 13 },
  { id: '14-17', min: 14, max: 17 },
] as const;

export const NIVELES = [
  { id: 'inicio', label: 'Inicio' },
  { id: 'medio', label: 'Medio' },
  { id: 'avanzado', label: 'Avanzado' },
] as const;

export const OBJETIVOS = [
  { id: 'calentar', label: 'Calentar' },
  { id: 'derecha', label: 'Derecha' },
  { id: 'reves', label: 'Revés' },
  { id: 'saque', label: 'Saque' },
  { id: 'volea', label: 'Volea' },
  { id: 'pies', label: 'Pies' },
] as const;

export const ESPACIOS = [
  { id: 'pista', label: 'Pista entera' },
  { id: 'media', label: 'Media pista' },
  { id: 'mini', label: 'Minicancha' },
] as const;

export const MATERIALES = [
  { id: 'pelotas', label: 'Pelotas' },
  { id: 'conos', label: 'Conos' },
  { id: 'aros', label: 'Aros' },
  { id: 'red', label: 'Red' },
] as const;

export const etiqueta = (lista: readonly { id: string; label: string }[], id: string | null) =>
  lista.find((x) => x.id === id)?.label ?? '';

// "8-13" a partir de edad_min y edad_max
export const textoEdad = (min: number | null, max: number | null) =>
  min === null || max === null ? '' : `${min}-${max}`;

export const textoJugadores = (min: number, max: number) => (min === max ? `${min} jug.` : `${min}-${max} jug.`);

export const MAX_IMAGENES = 5;
export const MAX_ELEMENTOS = 40;
export const MAX_PASOS = 3;

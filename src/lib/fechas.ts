// Fechas de las clases. Los grupos tienen un día de la semana (1 = lunes … 7 = domingo)
// y una hora; la próxima clase se calcula a partir de ahí, en la hora del dispositivo.

const DIAS = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

export const nombreDia = (dia: number) => DIAS[dia] ?? '';

// "17:00:00" → "17:00"
export const horaCorta = (hora: string) => hora.slice(0, 5);

function aFecha(base: Date, hora: string): Date {
  const [h, m] = hora.split(':').map(Number);
  const d = new Date(base);
  d.setHours(h, m ?? 0, 0, 0);
  return d;
}

// Próxima vez que ocurre una clase (hoy mismo si todavía no ha empezado)
export function proximaOcurrencia(dia: number, hora: string, ahora = new Date()): Date {
  const hoyDia = ahora.getDay() === 0 ? 7 : ahora.getDay();
  let dias = (dia - hoyDia + 7) % 7;
  const base = new Date(ahora);
  base.setDate(base.getDate() + dias);
  let cuando = aFecha(base, hora);
  if (cuando.getTime() <= ahora.getTime()) {
    base.setDate(base.getDate() + 7);
    cuando = aFecha(base, hora);
  }
  return cuando;
}

const mismaFecha = (a: Date, b: Date) =>
  a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();

// "Hoy", "Mañana" o el nombre del día
export function etiquetaDia(cuando: Date, ahora = new Date()): string {
  if (mismaFecha(cuando, ahora)) return 'Hoy';
  const manana = new Date(ahora);
  manana.setDate(manana.getDate() + 1);
  if (mismaFecha(cuando, manana)) return 'Mañana';
  return DIAS[cuando.getDay() === 0 ? 7 : cuando.getDay()];
}

export type GrupoHorario = { id: string; nombre: string; dia: number; hora: string };

// El grupo cuya clase es la más próxima
export function proximaClase<T extends GrupoHorario>(grupos: T[], ahora = new Date()) {
  let mejor: { grupo: T; cuando: Date } | null = null;
  for (const grupo of grupos) {
    const cuando = proximaOcurrencia(grupo.dia, grupo.hora, ahora);
    if (!mejor || cuando < mejor.cuando) mejor = { grupo, cuando };
  }
  return mejor && { ...mejor, etiqueta: `${etiquetaDia(mejor.cuando, ahora)} ${horaCorta(mejor.grupo.hora)}` };
}

// Fecha de una sesión ('2026-10-09') como "Ayer", "Hoy" o "Lunes 5"
export function etiquetaSesion(fecha: string, ahora = new Date()): string {
  const [y, m, d] = fecha.split('-').map(Number);
  const f = new Date(y, m - 1, d);
  const ayer = new Date(ahora);
  ayer.setDate(ayer.getDate() - 1);
  if (mismaFecha(f, ahora)) return 'Hoy';
  if (mismaFecha(f, ayer)) return 'Ayer';
  return `${DIAS[f.getDay() === 0 ? 7 : f.getDay()]} ${d}`;
}

export const hoyISO = (ahora = new Date()) =>
  `${ahora.getFullYear()}-${String(ahora.getMonth() + 1).padStart(2, '0')}-${String(ahora.getDate()).padStart(2, '0')}`;

export function edad(anioNacimiento: number, ahora = new Date()) {
  return ahora.getFullYear() - anioNacimiento;
}

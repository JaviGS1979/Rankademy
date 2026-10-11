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

// 1 = lunes … 7 = domingo
export const diaSemana = (d = new Date()) => (d.getDay() === 0 ? 7 : d.getDay());

// '2026-10-09' como fecha local (sin desfase por zona horaria)
export function deISO(fecha: string): Date {
  const [y, m, d] = fecha.split('-').map(Number);
  return new Date(y, m - 1, d);
}

// Fechas (ISO) en las que un grupo de ese día da clase: las `atras` anteriores a la
// de hoy o la próxima y las `adelante` siguientes. Con atras = 2 nunca pasa de 14 días
// hacia atrás, que es el plazo para corregir una lista.
export function ocurrenciasDelGrupo(dia: number, ahora = new Date(), atras = 2, adelante = 3): string[] {
  const base = new Date(ahora.getFullYear(), ahora.getMonth(), ahora.getDate());
  base.setDate(base.getDate() + ((dia - diaSemana(ahora) + 7) % 7));
  const fechas: string[] = [];
  for (let i = -atras; i < adelante; i++) {
    const f = new Date(base);
    f.setDate(base.getDate() + 7 * i);
    fechas.push(hoyISO(f));
  }
  return fechas;
}

// "Hoy", "Mañana", "Ayer" o "Lunes 5"
export function etiquetaFecha(fecha: string, ahora = new Date()): string {
  const f = deISO(fecha);
  const manana = new Date(ahora);
  manana.setDate(manana.getDate() + 1);
  if (mismaFecha(f, manana)) return 'Mañana';
  return etiquetaSesion(fecha, ahora);
}

// "17:00" → minutos desde medianoche; null si no es una hora válida
export function horaValida(texto: string): string | null {
  const m = /^(\d{1,2})[:.hH]?(\d{2})$/.exec(texto.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h > 23 || min > 59) return null;
  return `${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')}`;
}

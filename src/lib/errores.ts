// Traduce los errores de Supabase a mensajes para el usuario.
// Los de nuestras funciones SQL ya vienen en español y se muestran tal cual.
export function mensajeError(e: unknown): string {
  const msg = (e as { message?: string })?.message ?? String(e);
  const m = msg.toLowerCase();
  if (m.includes('rate limit') || m.includes('only request this after') || m.includes('too many'))
    return 'Has pedido demasiados códigos. Espera unos minutos y vuelve a intentarlo.';
  if (m.includes('expired') || (m.includes('invalid') && m.includes('token')))
    return 'El código no es correcto o ha caducado. Pide uno nuevo.';
  if (m.includes('signups not allowed') || m.includes('user not found'))
    return 'No hay ninguna cuenta con ese correo. Vuelve atrás y pulsa "Empezar".';
  if (m.includes('unable to validate email') || m.includes('invalid email'))
    return 'Ese correo no parece válido.';
  if (m.includes('network') || m.includes('fetch'))
    return 'Sin conexión. Comprueba tu internet y vuelve a intentarlo.';
  return msg;
}

export const correoValido = (c: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(c.trim());
// Formato del código de escuela: AAA-999 (sin I, O, 0, 1)
export const normalizarCodigo = (c: string) => {
  const limpio = c.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6);
  return limpio.length > 3 ? `${limpio.slice(0, 3)}-${limpio.slice(3)}` : limpio;
};
export const codigoValido = (c: string) => /^[A-HJ-NP-Z2-9]{3}-[A-HJ-NP-Z2-9]{3}$/.test(c);

// Código de alumno que da la escuela a la familia: AAAA-9999
export const normalizarCodigoAlumno = (c: string) => {
  const limpio = c.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 8);
  return limpio.length > 4 ? `${limpio.slice(0, 4)}-${limpio.slice(4)}` : limpio;
};
export const codigoAlumnoValido = (c: string) => /^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/.test(c);

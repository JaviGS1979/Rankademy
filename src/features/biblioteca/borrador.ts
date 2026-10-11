import type { DatosEjercicio } from '@/lib/api';
import type { Parecido } from '@/lib/tipos';

// Para pasar el ejercicio a medio publicar de "Nuevo ejercicio" a "Ya existe uno parecido"
// sin meterlo en la dirección de la pantalla.
let borrador: DatosEjercicio | null = null;
let parecidos: Parecido[] = [];

export function guardarBorrador(d: DatosEjercicio, p: Parecido[]) {
  borrador = d;
  parecidos = p;
}
export const leerBorrador = () => ({ borrador, parecidos });
export function limpiarBorrador() {
  borrador = null;
  parecidos = [];
}

// Cuando "Ya existe uno parecido" termina (se publicó o se eligió el existente), el formulario que
// quedó debajo ya no sirve: al volver a él se cierra solo.
let terminado = false;
export const marcarTerminado = () => {
  terminado = true;
  limpiarBorrador();
};
export function consumirTerminado() {
  const v = terminado;
  terminado = false;
  return v;
}

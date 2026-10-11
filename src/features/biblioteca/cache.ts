import AsyncStorage from '@react-native-async-storage/async-storage';
import { detalleEjercicio } from '@/lib/api';
import type { DetalleEjercicio } from '@/lib/tipos';

const clave = (id: string) => `ejercicio:${id}`;
const esDeRed = (e: unknown) => /network|fetch|conexi|timeout/i.test((e as { message?: string })?.message ?? String(e));

// Detalle de un ejercicio. Cada vez que se abre con conexión se guarda en el
// dispositivo, para poder verlo en la pista sin cobertura.
export async function detalleConCache(id: string): Promise<{ detalle: DetalleEjercicio; sinConexion: boolean }> {
  try {
    const detalle = await detalleEjercicio(id);
    AsyncStorage.setItem(clave(id), JSON.stringify(detalle)).catch(() => {});
    return { detalle, sinConexion: false };
  } catch (e) {
    if (!esDeRed(e)) throw e;
    let guardado: string | null = null;
    try {
      guardado = await AsyncStorage.getItem(clave(id));
    } catch {}
    if (!guardado) throw e;
    return { detalle: JSON.parse(guardado) as DetalleEjercicio, sinConexion: true };
  }
}

export function olvidarDetalle(id: string) {
  AsyncStorage.removeItem(clave(id)).catch(() => {});
}

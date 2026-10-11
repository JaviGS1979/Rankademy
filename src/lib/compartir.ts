import { Platform, Share } from 'react-native';
import { avisar } from './avisar';

// Comparte un texto con el menú del sistema; si no está disponible (web), lo enseña para copiarlo
export async function compartirTexto(titulo: string, mensaje: string) {
  if (Platform.OS === 'web' && !(navigator as Navigator & { share?: unknown }).share) {
    return avisar(titulo, mensaje);
  }
  try {
    await Share.share({ message: mensaje });
  } catch {
    avisar(titulo, mensaje);
  }
}

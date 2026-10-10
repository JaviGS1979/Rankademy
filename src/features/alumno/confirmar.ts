import { useCallback, useState } from 'react';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { confirmarAsistencia } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import type { Perfil } from '@/lib/tipos';

// Confirma la asistencia y abre el resumen con lo ganado
export function useConfirmar(perfil: Perfil, alTerminar?: () => void) {
  const router = useRouter();
  const [confirmando, setConfirmando] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const confirmar = useCallback(
    async (sesionId: string) => {
      setError(null);
      setConfirmando(sesionId);
      try {
        const r = await confirmarAsistencia(sesionId, perfil.id);
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
        alTerminar?.();
        router.push({ pathname: '/resumen', params: { datos: JSON.stringify(r), nombre: perfil.nombre } });
      } catch (e) {
        setError(mensajeError(e));
      } finally {
        setConfirmando(null);
      }
    },
    [perfil.id, perfil.nombre, router, alTerminar],
  );

  return { confirmar, confirmando, error };
}

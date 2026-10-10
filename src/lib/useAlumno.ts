import { useCallback, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import {
  avataresDesbloqueados, escuelasDelPerfil, gruposDelAlumno, pendientesDeConfirmar, progreso,
} from './api';
import { mensajeError } from './errores';
import { proximaClase } from './fechas';
import type { EstadoEscuelaPerfil, GrupoAlumno, Pendiente, Progreso } from './tipos';

export type DatosAlumno = {
  progreso: Progreso;
  grupos: GrupoAlumno[];
  pendientes: Pendiente[];
  escuelas: EstadoEscuelaPerfil[];
  avatares: number;
  proxima: ReturnType<typeof proximaClase<GrupoAlumno>>;
};

// Carga (y recarga al volver a la pantalla) todo lo que necesita el inicio del alumno
export function useAlumno(perfilId: string | null) {
  const [datos, setDatos] = useState<DatosAlumno | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refrescando, setRefrescando] = useState(false);

  const cargar = useCallback(async () => {
    if (!perfilId) return;
    try {
      const [p, grupos, pendientes, escuelas, av] = await Promise.all([
        progreso(perfilId),
        gruposDelAlumno(perfilId),
        pendientesDeConfirmar(perfilId),
        escuelasDelPerfil(perfilId),
        avataresDesbloqueados(perfilId),
      ]);
      setDatos({ progreso: p, grupos, pendientes, escuelas, avatares: av.length, proxima: proximaClase(grupos) });
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [perfilId]);

  useFocusEffect(
    useCallback(() => {
      cargar();
    }, [cargar]),
  );

  const refrescar = useCallback(async () => {
    setRefrescando(true);
    await cargar();
    setRefrescando(false);
  }, [cargar]);

  return { datos, error, refrescando, refrescar, cargar };
}

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { misEscuelasStaff } from './api';
import { useSesion } from './sesion';
import type { EscuelaStaff } from './tipos';

const CLAVE = 'escuela_activa';

type Estado = {
  escuelas: EscuelaStaff[];
  actual: EscuelaStaff | null;
  esDirector: boolean;
  cargando: boolean;
  elegir: (id: string) => void;
  recargar: () => Promise<void>;
};

const Ctx = createContext<Estado>({
  escuelas: [],
  actual: null,
  esDirector: false,
  cargando: true,
  elegir: () => {},
  recargar: async () => {},
});

// Escuelas donde la persona dirige o entrena, y cuál está viendo ahora (se recuerda)
export function EscuelaProvider({ children }: { children: ReactNode }) {
  const { session } = useSesion();
  const userId = session?.user.id ?? null;
  const [escuelas, setEscuelas] = useState<EscuelaStaff[]>([]);
  const [actualId, setActualId] = useState<string | null>(null);
  const [cargadoPara, setCargadoPara] = useState<string | null>(null);
  const cargando = userId !== null && cargadoPara !== userId;

  const recargar = useCallback(async () => {
    if (!userId) return;
    try {
      const lista = await misEscuelasStaff();
      setEscuelas(lista);
      let guardada: string | null = null;
      try {
        guardada = await AsyncStorage.getItem(CLAVE);
      } catch {}
      setActualId((previa) => {
        const candidata = previa ?? guardada;
        return candidata && lista.some((e) => e.id === candidata) ? candidata : (lista[0]?.id ?? null);
      });
    } catch {
      // Sin red: se mantiene lo que hubiera
    } finally {
      setCargadoPara(userId);
    }
  }, [userId]);

  useEffect(() => {
    recargar();
  }, [recargar]);

  const elegir = useCallback((id: string) => {
    setActualId(id);
    AsyncStorage.setItem(CLAVE, id).catch(() => {});
  }, []);

  const valor = useMemo<Estado>(() => {
    const actual = escuelas.find((e) => e.id === actualId) ?? null;
    return { escuelas, actual, esDirector: actual?.rol === 'director', cargando, elegir, recargar };
  }, [escuelas, actualId, cargando, elegir, recargar]);
  return <Ctx.Provider value={valor}>{children}</Ctx.Provider>;
}

export const useEscuela = () => useContext(Ctx);

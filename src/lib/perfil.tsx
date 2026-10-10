import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { misPerfiles } from './api';
import { useSesion } from './sesion';
import type { Perfil } from './tipos';

const CLAVE = 'perfil_activo';

type Estado = {
  perfiles: Perfil[];
  activo: Perfil | null;
  cargando: boolean;
  elegir: (id: string) => void;
  recargar: () => Promise<void>;
};

const Ctx = createContext<Estado>({
  perfiles: [],
  activo: null,
  cargando: true,
  elegir: () => {},
  recargar: async () => {},
});

// Perfiles de hijo de la cuenta y cuál está jugando ahora (se recuerda entre sesiones)
export function PerfilProvider({ children }: { children: ReactNode }) {
  const { session } = useSesion();
  const [perfiles, setPerfiles] = useState<Perfil[]>([]);
  const [activoId, setActivoId] = useState<string | null>(null);
  // Usuario para el que ya se han cargado los perfiles: evita un instante "vacío" tras iniciar sesión
  const [cargadoPara, setCargadoPara] = useState<string | null>(null);
  const userId = session?.user.id ?? null;
  const cargando = userId !== null && cargadoPara !== userId;

  const recargar = useCallback(async () => {
    if (!userId) {
      setPerfiles([]);
      setActivoId(null);
      setCargadoPara(null);
      return;
    }
    try {
      const lista = await misPerfiles();
      setPerfiles(lista);
      let guardado: string | null = null;
      try {
        guardado = await AsyncStorage.getItem(CLAVE);
      } catch {}
      setActivoId((previo) => {
        const candidato = previo ?? guardado;
        if (candidato && lista.some((p) => p.id === candidato)) return candidato;
        return lista.length === 1 ? lista[0].id : null;
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
    setActivoId(id);
    AsyncStorage.setItem(CLAVE, id).catch(() => {});
  }, []);

  const valor = useMemo<Estado>(
    () => ({ perfiles, activo: perfiles.find((p) => p.id === activoId) ?? null, cargando, elegir, recargar }),
    [perfiles, activoId, cargando, elegir, recargar],
  );
  return <Ctx.Provider value={valor}>{children}</Ctx.Provider>;
}

export const usePerfiles = () => useContext(Ctx);

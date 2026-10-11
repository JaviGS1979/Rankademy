import { useCallback, useEffect, useRef, useState } from 'react';
import { bibliotecaEjercicios, sinFiltros, type FiltrosBiblioteca } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import type { ResumenEjercicio } from '@/lib/tipos';

const PAGINA = 30;

// Búsqueda en la biblioteca con filtros: espera un instante al escribir y carga por páginas.
export function useBiblioteca(mios = false) {
  const [filtros, setFiltros] = useState<FiltrosBiblioteca>(sinFiltros);
  const [items, setItems] = useState<ResumenEjercicio[] | null>(null);
  const [hayMas, setHayMas] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [cargandoMas, setCargandoMas] = useState(false);
  // Solo vale la respuesta de la última búsqueda
  const version = useRef(0);

  const buscar = useCallback(async () => {
    const mia = ++version.current;
    try {
      const r = await bibliotecaEjercicios(filtros, { mios, limite: PAGINA });
      if (mia !== version.current) return;
      setItems(r);
      setHayMas(r.length === PAGINA);
      setError(null);
    } catch (e) {
      if (mia !== version.current) return;
      setError(mensajeError(e));
      setItems((v) => v ?? []);
    }
  }, [filtros, mios]);

  useEffect(() => {
    const espera = setTimeout(buscar, filtros.texto ? 300 : 0);
    return () => clearTimeout(espera);
  }, [buscar, filtros.texto]);

  const verMas = async () => {
    if (!items) return;
    setCargandoMas(true);
    try {
      const r = await bibliotecaEjercicios(filtros, { mios, limite: PAGINA, desde: items.length });
      setItems([...items, ...r.filter((x) => !items.some((y) => y.id === x.id))]);
      setHayMas(r.length === PAGINA);
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setCargandoMas(false);
    }
  };

  return { filtros, setFiltros, items, hayMas, error, verMas, cargandoMas, recargar: buscar };
}

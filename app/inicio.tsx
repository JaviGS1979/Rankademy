import { useEffect, useState } from 'react';
import { Redirect, type Href } from 'expo-router';
import { Cargando, Screen } from '@/components';
import { misEscuelasStaff } from '@/lib/api';
import { usePerfiles } from '@/lib/perfil';

// Punto de entrada tras iniciar sesión: decide a dónde ir.
//  - un hijo: directo a su inicio; varios: ¿quién juega hoy?
//  - sin hijos y con una escuela que dirige o entrena: su zona de escuela
//  - sin hijos y sin escuela aprobada: Mis escuelas (para unirse o crear una)
export default function Inicio() {
  const { perfiles, activo, cargando } = usePerfiles();
  const [destinoSinHijos, setDestinoSinHijos] = useState<Href | null>(null);
  const sinHijos = !cargando && perfiles.length === 0;

  useEffect(() => {
    if (!sinHijos) return;
    let vigente = true;
    misEscuelasStaff()
      .then((l) => vigente && setDestinoSinHijos(l.length > 0 ? '/escuela' : '/mis-escuelas'))
      .catch(() => vigente && setDestinoSinHijos('/mis-escuelas'));
    return () => {
      vigente = false;
    };
  }, [sinHijos]);

  if (cargando || (sinHijos && !destinoSinHijos)) {
    return (
      <Screen scroll={false}>
        <Cargando />
      </Screen>
    );
  }
  if (sinHijos && destinoSinHijos) return <Redirect href={destinoSinHijos} />;
  if (perfiles.length === 1 && activo) return <Redirect href="/alumno" />;
  return <Redirect href="/selector-perfil" />;
}

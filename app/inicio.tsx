import { Redirect } from 'expo-router';
import { Cargando, Screen } from '@/components';
import { usePerfiles } from '@/lib/perfil';

// Punto de entrada tras iniciar sesión: decide a dónde ir según los perfiles de hijo.
//  - sin hijos: Mis escuelas (director, entrenador, o familia que aún no ha añadido ninguno)
//  - un hijo: directo a su inicio
//  - varios: ¿quién juega hoy?
export default function Inicio() {
  const { perfiles, activo, cargando } = usePerfiles();
  if (cargando) {
    return (
      <Screen scroll={false}>
        <Cargando />
      </Screen>
    );
  }
  if (perfiles.length === 0) return <Redirect href="/mis-escuelas" />;
  if (perfiles.length === 1 && activo) return <Redirect href="/alumno" />;
  return <Redirect href="/selector-perfil" />;
}

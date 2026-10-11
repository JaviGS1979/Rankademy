import { Redirect, Stack } from 'expo-router';
import { Cargando, Screen } from '@/components';
import { EscuelaProvider, useEscuela } from '@/lib/escuela';
import { colors } from '@/theme';

// Zona del director y del entrenador. Las pestañas están en (tabs); las demás
// pantallas (grupo, lista…) se apilan encima, con su gesto de volver.
export default function EscuelaLayout() {
  return (
    <EscuelaProvider>
      <Contenido />
    </EscuelaProvider>
  );
}

function Contenido() {
  const { cargando, actual } = useEscuela();
  if (cargando) {
    return (
      <Screen scroll={false}>
        <Cargando />
      </Screen>
    );
  }
  if (!actual) return <Redirect href="/mis-escuelas" />;
  return <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.bg } }} />;
}

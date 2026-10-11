import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import * as SplashScreen from 'expo-splash-screen';
import { useFonts } from 'expo-font';
import { BarlowCondensed_700Bold, BarlowCondensed_800ExtraBold } from '@expo-google-fonts/barlow-condensed';
import {
  Figtree_400Regular,
  Figtree_600SemiBold,
  Figtree_700Bold,
  Figtree_800ExtraBold,
} from '@expo-google-fonts/figtree';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { colors } from '@/theme';
import { SesionProvider, useSesion } from '@/lib/sesion';
import { PerfilProvider } from '@/lib/perfil';

SplashScreen.preventAutoHideAsync().catch(() => {});

export default function RootLayout() {
  const [loaded, error] = useFonts({
    BarlowCondensed_700Bold,
    BarlowCondensed_800ExtraBold,
    Figtree_400Regular,
    Figtree_600SemiBold,
    Figtree_700Bold,
    Figtree_800ExtraBold,
  });

  if (!loaded && !error) return null;

  return (
    <GestureHandlerRootView style={{ flex: 1, backgroundColor: colors.ink }}>
      <SafeAreaProvider>
        <SesionProvider>
          <PerfilProvider>
            <StatusBar style="auto" />
            <Navegacion />
          </PerfilProvider>
        </SesionProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

function Navegacion() {
  const { session, cargando } = useSesion();

  // La pantalla de arranque nativa se mantiene hasta saber si hay sesión
  useEffect(() => {
    if (!cargando) SplashScreen.hideAsync().catch(() => {});
  }, [cargando]);

  if (cargando) return null;

  // Pila nativa: transiciones y gesto de volver del sistema.
  // Las pantallas sin permiso desaparecen de la pila al entrar o salir, así
  // que "Atrás" nunca vuelve al registro tras iniciar sesión. El orden importa:
  // la primera pantalla permitida es la de inicio.
  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.bg } }}>
      <Stack.Protected guard={!session}>
        <Stack.Screen name="index" />
        <Stack.Screen name="soy" />
        <Stack.Screen name="registro" />
        <Stack.Screen name="entrar" />
      </Stack.Protected>
      <Stack.Protected guard={!!session}>
        <Stack.Screen name="inicio" />
        <Stack.Screen name="selector-perfil" />
        <Stack.Screen name="alumno" />
        <Stack.Screen name="resumen" />
        <Stack.Screen name="mis-escuelas" />
        <Stack.Screen name="crear-escuela" />
        <Stack.Screen name="anadir-escuela" />
        <Stack.Screen name="anadir-hijo" />
        <Stack.Screen name="vincular-alumno" />
        <Stack.Screen name="escuela" />
      </Stack.Protected>
      {/* Durante el cambio de "sin sesión" a "con sesión" */}
      <Stack.Screen name="verificar" />
    </Stack>
  );
}

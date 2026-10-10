import { Redirect, Tabs } from 'expo-router';
import { Icon, type IconName } from '@/components';
import { usePerfiles } from '@/lib/perfil';
import { colors, fonts } from '@/theme';

const icono = (name: IconName) =>
  function TabIcon({ color }: { color: unknown }) {
    return <Icon name={name} color={String(color)} />;
  };

// Barra de pestañas inferior del alumno Gamer. El perfil Mini no la usa: sus
// pantallas se manejan con botones grandes.
export default function AlumnoLayout() {
  const { activo, cargando } = usePerfiles();
  if (cargando) return null;
  if (!activo) return <Redirect href="/inicio" />;
  const mini = activo.nivel === 'mini';

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.blue,
        tabBarInactiveTintColor: colors.ink2,
        tabBarLabelStyle: { fontFamily: fonts.bodyBold, fontSize: 12 },
        tabBarStyle: mini ? { display: 'none' } : { backgroundColor: colors.white, borderTopColor: colors.line, minHeight: 64 },
        sceneStyle: { backgroundColor: mini ? colors.miniBg : colors.bg },
      }}
    >
      <Tabs.Screen name="index" options={{ title: 'Inicio', tabBarIcon: icono('home') }} />
      <Tabs.Screen name="progreso" options={{ title: 'Progreso', tabBarIcon: icono('chart') }} />
      <Tabs.Screen name="ranking" options={{ title: 'Ranking', tabBarIcon: icono('trophy') }} />
      <Tabs.Screen name="ejercicios" options={{ title: 'Ejercicios', tabBarIcon: icono('list') }} />
      <Tabs.Screen name="avatares" options={{ href: null }} />
    </Tabs>
  );
}

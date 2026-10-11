import { Tabs } from 'expo-router';
import { Icon, type IconName } from '@/components';
import { useEscuela } from '@/lib/escuela';
import { colors, fonts } from '@/theme';

const icono = (name: IconName) =>
  function TabIcon({ color }: { color: unknown }) {
    return <Icon name={name} color={String(color)} />;
  };

export default function EscuelaTabs() {
  const { esDirector } = useEscuela();
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.blue,
        tabBarInactiveTintColor: colors.ink2,
        tabBarLabelStyle: { fontFamily: fonts.bodyBold, fontSize: 12 },
        tabBarStyle: { backgroundColor: colors.white, borderTopColor: colors.line, minHeight: 64 },
        sceneStyle: { backgroundColor: colors.bg },
      }}
    >
      <Tabs.Screen name="index" options={{ title: 'Hoy', tabBarIcon: icono('home') }} />
      <Tabs.Screen name="horario" options={{ title: 'Horario', tabBarIcon: icono('calendar') }} />
      <Tabs.Screen name="biblioteca" options={{ title: 'Biblioteca', tabBarIcon: icono('list') }} />
      <Tabs.Screen name="personas" options={{ title: 'Personas', tabBarIcon: icono('coach'), href: esDirector ? undefined : null }} />
      <Tabs.Screen name="panel" options={{ title: 'Escuela', tabBarIcon: icono('school') }} />
    </Tabs>
  );
}

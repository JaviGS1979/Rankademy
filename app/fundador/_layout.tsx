import { useEffect, useState } from 'react';
import { Redirect, Tabs } from 'expo-router';
import { Cargando, Icon, Screen, type IconName } from '@/components';
import { esFundador } from '@/lib/api';
import { colors, fonts } from '@/theme';

const icono = (name: IconName) =>
  function TabIcon({ color }: { color: unknown }) {
    return <Icon name={name} color={String(color)} />;
  };

// Panel del fundador. Solo entra quien está en la tabla de fundadores; para cualquier otra persona esta zona
// no existe (y la base de datos tampoco le da nada).
export default function FundadorLayout() {
  const [permiso, setPermiso] = useState<boolean | null>(null);
  useEffect(() => {
    esFundador().then(setPermiso).catch(() => setPermiso(false));
  }, []);

  if (permiso === null) {
    return (
      <Screen scroll={false}>
        <Cargando />
      </Screen>
    );
  }
  if (!permiso) return <Redirect href="/inicio" />;

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
      <Tabs.Screen name="index" options={{ title: 'Resumen', tabBarIcon: icono('chart') }} />
      <Tabs.Screen name="piloto" options={{ title: 'Piloto', tabBarIcon: icono('school') }} />
      <Tabs.Screen name="alertas" options={{ title: 'Alertas', tabBarIcon: icono('flame') }} />
    </Tabs>
  );
}

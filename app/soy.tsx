import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useRouter, type Href } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Icon, Screen, type IconName } from '@/components';
import { colors, fonts, type as t } from '@/theme';

type Rol = {
  icon: IconName;
  title: string;
  desc: string;
  href: Href;
  bg: string;
  fg: string;
};

const roles: Rol[] = [
  { icon: 'school', title: 'Director de escuela', desc: 'Crea tu escuela y comparte el código.', href: '/crear-escuela', bg: colors.ink, fg: colors.lime },
  { icon: 'coach', title: 'Entrenador', desc: 'Pasa lista y usa la biblioteca de ejercicios.', href: { pathname: '/registro', params: { rol: 'entrenador' } }, bg: colors.blue, fg: colors.white },
  { icon: 'home', title: 'Alumno', desc: 'Tú o tu familia: racha, avatares y posición.', href: { pathname: '/registro', params: { rol: 'alumno' } }, bg: colors.lime, fg: colors.ink },
];

export default function Soy() {
  const router = useRouter();
  return (
    <Screen back title="Soy…" subtitle="Elige una opción. Podrás cambiarla más tarde.">
      {roles.map((r) => (
        <Pressable
          key={r.title}
          accessibilityRole="button"
          accessibilityLabel={`${r.title}. ${r.desc}`}
          onPress={() => {
            Haptics.selectionAsync().catch(() => {});
            router.push(r.href);
          }}
          style={({ pressed }) => [styles.card, pressed && { opacity: 0.85 }]}
        >
          <View style={[styles.badge, { backgroundColor: r.bg }]}>
            <Icon name={r.icon} size={32} color={r.fg} />
          </View>
          <View style={styles.grow}>
            <Text style={t.h3}>{r.title}</Text>
            <Text style={styles.desc}>{r.desc}</Text>
          </View>
          <Icon name="next" />
        </Pressable>
      ))}
    </Screen>
  );
}

const styles = StyleSheet.create({
  card: {
    minHeight: 120,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    padding: 16,
    borderRadius: 20,
    borderWidth: 2,
    borderColor: colors.ink,
    backgroundColor: colors.card,
  },
  badge: { width: 64, height: 64, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  grow: { flex: 1, gap: 4 },
  desc: { fontFamily: fonts.body, fontSize: 15, color: colors.ink2 },
});

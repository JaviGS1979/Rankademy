import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { Image } from 'expo-image';
import * as Haptics from 'expo-haptics';
import { Icon, Screen } from '@/components';
import { cerrarSesion } from '@/lib/api';
import { miniaturas } from '@/lib/avatares';
import { edad } from '@/lib/fechas';
import { usePerfiles } from '@/lib/perfil';
import { colors, fonts, type as t } from '@/theme';

export default function SelectorPerfil() {
  const router = useRouter();
  const { perfiles, elegir } = usePerfiles();

  return (
    <Screen title={'¿Quién\njuega hoy?'} subtitle="Cuenta familiar">
      {perfiles.map((p) => (
        <Pressable
          key={p.id}
          accessibilityRole="button"
          accessibilityLabel={`${p.nombre}, perfil ${p.nivel === 'mini' ? 'Mini' : 'Gamer'}, ${edad(p.anio_nacimiento)} años`}
          onPress={() => {
            Haptics.selectionAsync().catch(() => {});
            elegir(p.id);
            router.replace('/alumno');
          }}
          style={({ pressed }) => [styles.card, pressed && { opacity: 0.85 }]}
        >
          <Image source={miniaturas[p.avatar ?? 'av01']} style={styles.av} contentFit="cover" />
          <View style={{ flex: 1, gap: 4 }}>
            <Text style={t.h3}>{p.nombre}</Text>
            <View style={styles.fila}>
              <View style={[styles.tag, { backgroundColor: p.nivel === 'mini' ? colors.lime : colors.blueLight }]}>
                <Text style={[styles.tagText, { color: p.nivel === 'mini' ? colors.ink : colors.blueDark }]}>
                  {p.nivel === 'mini' ? 'Mini' : 'Gamer'}
                </Text>
              </View>
              <Text style={styles.mut}>{edad(p.anio_nacimiento)} años</Text>
            </View>
          </View>
          <Icon name="next" />
        </Pressable>
      ))}

      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Añadir hijo"
        onPress={() => router.push('/anadir-hijo')}
        style={[styles.card, styles.añadir]}
      >
        <View style={styles.mas}>
          <Icon name="plus" size={28} color={colors.ink} />
        </View>
        <Text style={[t.h3, { flex: 1 }]}>Añadir hijo</Text>
      </Pressable>

      <View style={styles.enlaces}>
        <Pressable accessibilityRole="link" onPress={() => router.push('/mis-escuelas')} style={styles.enlace}>
          <Text style={styles.enlaceText}>Mis escuelas</Text>
        </Pressable>
        <Pressable accessibilityRole="button" onPress={() => cerrarSesion().catch(() => {})} style={styles.enlace}>
          <Text style={[styles.enlaceText, { color: colors.orange }]}>Cerrar sesión</Text>
        </Pressable>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  card: {
    minHeight: 96, flexDirection: 'row', alignItems: 'center', gap: 16, padding: 14,
    borderRadius: 20, borderWidth: 2, borderColor: colors.ink, backgroundColor: colors.card,
  },
  añadir: { borderStyle: 'dashed', borderColor: colors.ink2 },
  av: { width: 68, height: 68, borderRadius: 34 },
  mas: { width: 68, height: 68, borderRadius: 34, backgroundColor: colors.line, alignItems: 'center', justifyContent: 'center' },
  fila: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  tag: { height: 26, paddingHorizontal: 10, borderRadius: 999, justifyContent: 'center' },
  tagText: { fontFamily: fonts.bodyBold, fontSize: 12 },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  enlaces: { flexDirection: 'row', justifyContent: 'space-around', marginTop: 8 },
  enlace: { minHeight: 44, justifyContent: 'center', paddingHorizontal: 12 },
  enlaceText: { fontFamily: fonts.bodyBold, fontSize: 15, color: colors.blue },
});

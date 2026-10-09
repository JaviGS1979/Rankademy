import type { ReactNode } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRouter } from 'expo-router';
import { colors, fonts, touch, type as t } from '@/theme';
import { Icon } from './Icon';

type Props = {
  children: ReactNode;
  dark?: boolean;
  // Título grande de la cabecera y subtítulo opcional
  title?: string;
  subtitle?: string;
  back?: boolean;
  scroll?: boolean;
};

// Contenedor de pantalla: zonas seguras, teclado y cabecera con "Atrás".
// En web limita el ancho a 480 px para que la app móvil no se estire.
export function Screen({ children, dark, title, subtitle, back, scroll = true }: Props) {
  const router = useRouter();
  const bg = dark ? colors.ink : colors.bg;
  const Body = scroll ? ScrollView : View;

  return (
    <SafeAreaView style={[styles.root, { backgroundColor: bg }]}>
      <KeyboardAvoidingView
        style={styles.flex}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={styles.column}>
          {(back || title) && (
            <View style={styles.header}>
              {back && (
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel="Atrás"
                  onPress={() => (router.canGoBack() ? router.back() : router.replace('/'))}
                  style={styles.back}
                  hitSlop={8}
                >
                  <Icon name="back" color={dark ? colors.white : colors.ink} />
                  <Text style={[styles.backText, dark && { color: colors.white }]}>Atrás</Text>
                </Pressable>
              )}
              {title && (
                <Text style={[t.h1, { color: dark ? colors.white : colors.ink }]} accessibilityRole="header">
                  {title}
                </Text>
              )}
              {subtitle && (
                <Text style={[t.body, { color: dark ? colors.muted : colors.ink2 }]}>{subtitle}</Text>
              )}
            </View>
          )}
          <Body
            style={styles.flex}
            contentContainerStyle={scroll ? styles.bodyContent : undefined}
            keyboardShouldPersistTaps="handled"
          >
            {scroll ? children : <View style={[styles.flex, styles.bodyContent]}>{children}</View>}
          </Body>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  flex: { flex: 1 },
  column: { flex: 1, width: '100%', maxWidth: 480, alignSelf: 'center' },
  header: { paddingTop: 20, paddingHorizontal: 20, paddingBottom: 10, gap: 6 },
  back: { flexDirection: 'row', alignItems: 'center', gap: 4, minHeight: touch.min, marginLeft: -6 },
  backText: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  bodyContent: { paddingHorizontal: 20, paddingTop: 12, paddingBottom: 24, gap: 16, flexGrow: 1 },
});

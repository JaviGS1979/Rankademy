import type { ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { heroes, miniaturas } from '@/lib/avatares';
import { colors } from '@/theme';

type Props = {
  avatar: string | null;
  height: number;
  // Fondo de color cuando no hay imagen en cuerpo completo
  fondo?: string;
  children?: ReactNode;
};

// Cabecera con el avatar en grande y degradados arriba y abajo para leer el texto.
// Si el avatar no tiene imagen en cuerpo completo se muestra su miniatura en un círculo.
export function Heroe({ avatar, height, fondo = '#A65F3A', children }: Props) {
  const id = avatar ?? 'av01';
  const hero = heroes[id];
  return (
    <View style={[styles.root, { height, backgroundColor: fondo }]}>
      {hero ? (
        <Image source={hero} contentFit="cover" contentPosition={{ top: '30%', left: '50%' }} style={StyleSheet.absoluteFill} accessibilityLabel="Tu avatar" />
      ) : (
        <View style={styles.centro}>
          <Image source={miniaturas[id]} contentFit="cover" style={styles.circulo} accessibilityLabel="Tu avatar" />
        </View>
      )}
      <LinearGradient
        pointerEvents="none"
        colors={['rgba(15,29,46,0.6)', 'rgba(15,29,46,0)', 'rgba(15,29,46,0)', 'rgba(15,29,46,0.82)']}
        locations={[0, 0.24, 0.6, 1]}
        style={StyleSheet.absoluteFill}
      />
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { overflow: 'hidden', width: '100%' },
  centro: { ...(StyleSheet.absoluteFill as object), alignItems: 'center', justifyContent: 'center' },
  circulo: { width: 220, height: 220, borderRadius: 110, borderWidth: 6, borderColor: colors.lime },
});
